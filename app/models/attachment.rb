# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require "atom"
require "crocodoc"

# See the uploads controller and views for examples on how to use this model.
class Attachment < ActiveRecord::Base
  class UniqueRenameFailure < StandardError; end

  self.ignored_columns = %i[last_lock_at last_unlock_at enrollment_id cached_s3_url s3_url_cached_at
                            scribd_account_id scribd_user scribd_mime_type_id submitted_to_scribd_at scribd_doc scribd_attempts
                            cached_scribd_thumbnail last_inline_view local_filename]

  def self.display_name_order_by_clause(table = nil)
    col = table ? "#{table}.display_name" : "display_name"
    best_unicode_collation_key(col)
  end

  PERMITTED_ATTRIBUTES = %i[filename display_name locked position lock_at
                            unlock_at uploaded_data hidden viewed_at].freeze
  def self.permitted_attributes
    PERMITTED_ATTRIBUTES
  end

  EXCLUDED_COPY_ATTRIBUTES = %w[id root_attachment_id uuid folder_id user_id
                                filename namespace workflow_state root_account_id].freeze

  CLONING_ERROR_TYPE = "attachment_clone_url"

  BUTTONS_AND_ICONS = "buttons_and_icons"
  UNCATEGORIZED = "uncategorized"
  VALID_CATEGORIES = [BUTTONS_AND_ICONS, UNCATEGORIZED].freeze

  include HasContentTags
  include ContextModuleItem
  include SearchTermHelper
  include MasterCourses::Restrictor
  restrict_columns :content, [:display_name, :uploaded_data]
  restrict_columns :settings, %i[folder_id locked lock_at unlock_at usage_rights_id]
  restrict_columns :state, [:locked, :file_state]

  attr_accessor :podcast_associated_asset

  # this is a gross hack to work around freaking SubmissionComment#attachments=
  attr_accessor :ok_for_submission_comment

  belongs_to :context, exhaustive: false, polymorphic:
      [:account, :assessment_question, :assignment, :attachment,
       :content_export, :content_migration, :course, :eportfolio, :epub_export,
       :gradebook_upload, :group, :submission, :purgatory,
       { context_folder: "Folder", context_sis_batch: "SisBatch",
         context_outcome_import: "OutcomeImport",
         context_user: "User", quiz: "Quizzes::Quiz",
         quiz_statistics: "Quizzes::QuizStatistics",
         quiz_submission: "Quizzes::QuizSubmission" }]
  belongs_to :cloned_item
  belongs_to :folder
  belongs_to :user
  has_one :account_report, inverse_of: :attachment
  has_one :group_and_membership_importer, inverse_of: :attachment
  has_one :media_object
  has_many :submission_draft_attachments, inverse_of: :attachment
  has_many :submissions, -> { active }
  has_many :attachment_associations
  belongs_to :root_attachment, class_name: "Attachment"
  belongs_to :replacement_attachment, class_name: "Attachment"
  has_one :sis_batch
  has_one :thumbnail, -> { where(thumbnail: "thumb") }, foreign_key: "parent_id"
  has_many :thumbnails, foreign_key: "parent_id"
  has_many :children, foreign_key: :root_attachment_id, class_name: "Attachment"
  has_many :attachment_upload_statuses
  has_one :crocodoc_document
  has_one :canvadoc
  belongs_to :usage_rights
  has_many :canvadocs_annotation_contexts, inverse_of: :attachment
  has_many :discussion_entry_drafts, inverse_of: :attachment

  before_save :set_root_account_id
  before_save :infer_display_name
  before_save :default_values
  before_save :set_need_notify

  after_save :set_word_count

  before_validation :assert_attachment
  acts_as_list scope: :folder

  def self.file_store_config
    # Return existing value, even if nil, as long as it's defined
    @file_store_config ||= ConfigFile.load("file_store").dup
    @file_store_config ||= { "storage" => "local" }
    @file_store_config["path_prefix"] ||= @file_store_config["path"] || "tmp/files"
    @file_store_config["path_prefix"] = nil if @file_store_config["path_prefix"] == "tmp/files" && @file_store_config["storage"] == "s3"
    @file_store_config
  end

  def self.s3_config
    # Return existing value, even if nil, as long as it's defined
    return @s3_config if defined?(@s3_config)

    @s3_config ||= ConfigFile.load("amazon_s3")
  end

  def self.s3_storage?
    (file_store_config["storage"] rescue nil) == "s3" && s3_config
  end

  def self.local_storage?
    rv = !s3_storage?
    raise "Unknown storage type!" if rv && file_store_config["storage"] != "local"

    rv
  end

  def self.store_type
    if s3_storage?
      Attachments::S3Storage
    elsif local_storage?
      Attachments::LocalStorage
    else
      raise "Unknown storage system configured"
    end
  end

  def store
    @store ||= Attachment.store_type.new(self)
  end

  # Haaay... you're changing stuff here? Don't forget about the Thumbnail model
  # too, it cares about local vs s3 storage.
  has_attachment(
    storage: store_type.key,
    path_prefix: file_store_config["path_prefix"],
    s3_access: "private",
    thumbnails: { thumb: "128x128" },
    thumbnail_class: "Thumbnail"
  )

  # These callbacks happen after the attachment data is saved to disk/s3, or
  # immediately after save if no data is being uploading during this save cycle.
  # That means you can't rely on these happening in the same transaction as the save.
  after_save_and_attachment_processing :touch_context_if_appropriate
  after_save_and_attachment_processing :ensure_media_object

  # this mixin can be added to a has_many :attachments association, and it'll
  # handle finding replaced attachments. In other words, if an attachment fond
  # by id is deleted but an active attachment in the same context has the same
  # path, it'll return that attachment.
  module FindInContextAssociation
    def find(*a)
      find_with_possibly_replaced(super)
    end

    def find_by(**kwargs)
      return super unless kwargs.keys == [:id]

      find_with_possibly_replaced(super)
    end

    def find_all_by_id(ids)
      find_with_possibly_replaced(where(id: ids).to_a)
    end

    def find_with_possibly_replaced(a_or_as)
      case a_or_as
      when Attachment
        find_attachment_possibly_replaced(a_or_as)
      when Array
        a_or_as.map { |a| find_attachment_possibly_replaced(a) }
      end
    end

    def find_attachment_possibly_replaced(att)
      # if they found a deleted attachment by id, but there's an available
      # attachment in the same context and the same full path, we return that
      # instead, to emulate replacing a file without having to update every
      # by-id reference in every user content field.
      if respond_to?(:proxy_association)
        owner = proxy_association.owner
      end

      if att.deleted? && owner
        new_att = owner.attachments.where(id: att.replacement_attachment_id).first if att.replacement_attachment_id
        new_att ||= Folder.find_attachment_in_context_with_path(owner, att.full_display_path)
        new_att || att
      else
        att
      end
    end
  end

  RELATIVE_CONTEXT_TYPES = %w[Course Group User Account].freeze
  # returns true if the context is a type that supports relative file paths
  def self.relative_context?(context_class)
    RELATIVE_CONTEXT_TYPES.include?(context_class.to_s)
  end

  def touch_context_if_appropriate
    unless context_type == "ConversationMessage"
      self.class.connection.after_transaction_commit { touch_context }
    end
  end

  def run_before_attachment_saved
    @after_attachment_saved_workflow_state = workflow_state
    self.workflow_state = "unattached"
  end

  # this is a magic method that gets run by attachment-fu after it is done sending to s3,
  # note, that the time it takes to send to s3 is the bad guy.
  # It blocks and makes the user wait.
  def run_after_attachment_saved
    old_workflow_state = workflow_state
    if workflow_state == "unattached" && @after_attachment_saved_workflow_state
      self.workflow_state = @after_attachment_saved_workflow_state
      @after_attachment_saved_workflow_state = nil
    end

    if %w[pending_upload processing].include?(workflow_state)
      # we don't call .process here so that we don't have to go through another whole save cycle
      self.workflow_state = "processed"
    end

    # directly update workflow_state so we don't trigger another save cycle
    if old_workflow_state != workflow_state
      shard.activate do
        self.class.where(id: self).update_all(workflow_state: workflow_state)
      end
    end

    # try an infer encoding if it would be useful to do so
    delay.infer_encoding if encoding.nil? && content_type&.include?("text") && context_type != "SisBatch"
    if respond_to?(:process_attachment, true)
      automatic_thumbnail_sizes.each do |suffix|
        delay_if_production(singleton: "attachment_thumbnail_#{global_id}_#{suffix}")
          .create_thumbnail_size(suffix)
      end
    end
  end

  READ_FILE_CHUNK_SIZE = 4096
  def self.read_file_chunk_size
    READ_FILE_CHUNK_SIZE
  end

  def self.valid_utf8?(file)
    # validate UTF-8
    chunk = file.read(read_file_chunk_size)
    error_count = 0

    while chunk
      begin
        raise EncodingError unless chunk.dup.force_encoding("UTF-8").valid_encoding?
      rescue EncodingError
        error_count += 1
        if !file.eof? && error_count <= 4
          # we may have split a utf-8 character in the chunk - try to resolve it, but only to a point
          chunk << file.read(1)
          next
        else
          raise
        end
      end

      error_count = 0
      chunk = file.read(read_file_chunk_size)
    end
    file.close
    true
  rescue EncodingError
    false
  end

  def infer_encoding
    return unless encoding.nil?

    begin
      if self.class.valid_utf8?(self.open)
        self.encoding = "UTF-8"
        Attachment.where(id: self).update_all(encoding: "UTF-8")
      else
        self.encoding = ""
        Attachment.where(id: self).update_all(encoding: "")
      end
    rescue IOError => e
      logger.error("Error inferring encoding for attachment #{global_id}: #{e.message}")
    end
  end

  # this is here becase attachment_fu looks to make sure that parent_id is nil before it will create a thumbnail of something.
  # basically, it makes a false assumption that the thumbnail class is the same as the original class
  # which in our case is false because we use the Thumbnail model for the thumbnails.
  def parent_id; end

  attr_accessor :clone_updated

  def clone_for(context, dup = nil, options = {})
    if !cloned_item && !new_record?
      self.cloned_item = ClonedItem.create(original_item: self) # do we even use this for anything?
      shard.activate do
        Attachment.where(id: self).update_all(cloned_item_id: cloned_item.id) # don't touch it for no reason
      end
    end
    existing = context.attachments.active.find_by(id: self)

    options[:cloned_item_id] ||= cloned_item_id
    options[:migration_id] ||= CC::CCHelper.create_key(self)
    existing ||= Attachment.find_existing_attachment_for_clone(context, options.merge(active_only: true))
    return existing if existing && !options[:overwrite] && !options[:force_copy]

    existing ||= Attachment.find_existing_attachment_for_clone(context, options)

    dup ||= Attachment.new
    dup = existing if existing && options[:overwrite]

    excluded_atts = EXCLUDED_COPY_ATTRIBUTES
    excluded_atts += ["locked", "hidden"] if dup == existing && !options[:migration]&.for_master_course_import?
    dup.assign_attributes(attributes.except(*excluded_atts))
    dup.context = context
    if usage_rights && shard != context.shard
      attrs = usage_rights.attributes.slice("use_justification", "license", "legal_copyright")
      new_rights = context.usage_rights.detect { |ur| attrs.all? { |k, v| ur.attributes[k] == v } }
      new_rights ||= context.usage_rights.create(attrs)
      dup.usage_rights = new_rights
    end
    # avoid cycles (a -> b -> a) and self-references (a -> a) in root_attachment_id pointers
    if dup.new_record? || ![id, root_attachment_id].include?(dup.id)
      if shard == dup.shard
        dup.root_attachment_id = root_attachment_id || id
      elsif (existing_attachment = dup.find_existing_attachment_for_md5)
        dup.root_attachment = existing_attachment
      else
        dup.write_attribute(:filename, filename)
        Attachments::Storage.store_for_attachment(dup, self.open)
      end
    end
    dup.write_attribute(:filename, filename) unless dup.read_attribute(:filename) || dup.root_attachment_id?
    dup.migration_id = options[:migration_id]
    dup.mark_as_importing!(options[:migration]) if options[:migration]
    dup.shard.activate do
      if Attachment.s3_storage? && !instfs_hosted? && context.try(:root_account) && namespace != context.root_account.file_namespace
        dup.save_without_broadcasting!
        dup.make_rootless
        dup.change_namespace(context.root_account.file_namespace)
      end
    end
    dup.updated_at = Time.zone.now
    dup.clone_updated = true
    dup.set_publish_state_for_usage_rights unless locked?
    dup
  end

  def self.find_existing_attachment_for_clone(context, options = {})
    scope = context.attachments
    scope = scope.active if options[:active_only]
    if options[:migration_id] && options[:match_on_migration_id]
      scope.where(migration_id: options[:migration_id]).first
    elsif options[:cloned_item_id]
      scope.where(cloned_item_id: options[:cloned_item_id]).where(migration_id: [nil, options[:migration_id]]).first
    end
  end

  def copy_to_folder!(folder, on_duplicate = :rename)
    copy = clone_for(folder.context, nil, force_copy: true)
    copy.folder = folder
    copy.save!
    copy.handle_duplicates(on_duplicate)
    copy
  end

  def ensure_media_object
    return true if self.class.skip_media_object_creation?

    in_the_right_state = file_state == "available" && workflow_state !~ /^unattached/
    if in_the_right_state && media_entry_id == "maybe" &&
       content_type && content_type.match(/\A(video|audio)/)
      build_media_object
    end
  end

  def build_media_object
    tag = "add_media_files"
    delay = Setting.get("attachment_build_media_object_delay_seconds", 10.to_s).to_i
    progress = Progress.where(context_type: "Attachment", context_id: self, tag: tag).last
    progress ||= Progress.new context: self, tag: tag

    if progress.new_record? || !progress.pending?
      progress.reset!
      progress.process_job(MediaObject, :add_media_files, { run_at: delay.seconds.from_now, priority: Delayed::LOWER_PRIORITY, preserve_method_args: true, max_attempts: 5 }, self, false) && true
    else
      true
    end
  end

  def assert_attachment
    if !to_be_zipped? && !zipping? && !errored? && !deleted? && (!filename || !content_type || !downloadable?)
      errors.add(:base, t("errors.not_found", "File data could not be found"))
      throw :abort
    end
  end

  after_create :flag_as_recently_created
  attr_accessor :recently_created

  validates :context_id, :context_type, :workflow_state, :category, presence: true
  validates :content_type, length: { maximum: maximum_string_length, allow_blank: true }
  validates :category, inclusion: { in: VALID_CATEGORIES }

  # related_attachments: our root attachment, anyone who shares our root attachment,
  # and anyone who calls us a root attachment
  def related_attachments
    if root_attachment_id
      Attachment.where("id=? OR root_attachment_id=? OR (root_attachment_id=? AND id<>?)",
                       root_attachment_id, id, root_attachment_id, id)
    else
      Attachment.where(root_attachment_id: id)
    end
  end

  def children_and_self
    Attachment.where("id=? OR root_attachment_id=?", id, id)
  end

  TURNITINABLE_MIME_TYPES = %w[
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/pdf
    application/vnd.oasis.opendocument.text
    text/plain
    text/html
    application/rtf
    text/rtf
    text/richtext
    application/vnd.wordperfect
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
  ].to_set.freeze

  def turnitinable?
    TURNITINABLE_MIME_TYPES.include?(content_type)
  end

  def vericiteable?
    # accept any file format
    true
  end

  def flag_as_recently_created
    @recently_created = true
  end
  protected :flag_as_recently_created
  def recently_created?
    @recently_created || (created_at && created_at > Time.now - (60 * 5))
  end

  def after_extension
    res = extension[1..] rescue nil
    res = nil if res == "" || res == "unknown"
    res
  end

  def assert_file_extension
    self.content_type = nil if content_type == "application/x-unknown" || content_type&.include?("ERROR")
    self.content_type ||= mimetype(filename)
    if filename && filename.split(".").length < 2
      # we actually have better luck assuming zip files without extensions
      # are docx files than assuming they're zip files
      self.content_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" if content_type&.include?("zip")
      ext = extension
      write_attribute(:filename, filename + ext) unless ext == ".unknown"
    end
  end

  def extension
    res = (filename || "").match(/(\.[^.]*)\z/).to_s
    res = nil if res == ""
    if !res || res == ""
      res = File.mime_types[self.content_type].to_s rescue nil
      res = "." + res if res
    end
    res = nil if res == "."
    res ||= ".unknown"
    res.to_s
  end

  def default_values
    self.modified_at = Time.now.utc if modified_at.nil?
    self.display_name = nil if display_name && display_name.empty?
    self.display_name ||= unencoded_filename
    self.file_state ||= "available"
    assert_file_extension
    self.folder_id = nil if !folder || folder.context != context
    self.folder_id = nil if folder&.deleted? && !deleted?
    self.folder_id ||= Folder.unfiled_folder(context).id rescue nil
    self.folder_id ||= Folder.root_folders(context).first.id rescue nil
    if root_attachment && new_record?
      %i[md5 size content_type].each do |key|
        send("#{key}=", root_attachment.send(key))
      end
      self.workflow_state = "processed"
      write_attribute(:filename, root_attachment.filename)
    end
    self.context = folder.context if folder && (!context || (context.respond_to?(:is_a_context?) && context.is_a_context?))

    if respond_to?(:namespace=) && new_record?
      self.namespace = infer_namespace
    end

    self.media_entry_id ||= "maybe" if new_record? && previewable_media?
  end
  protected :default_values

  def set_root_account_id
    self.root_account_id = infer_root_account_id if namespace_changed? || new_record?
  end

  def set_word_count
    if word_count.nil? && !deleted? && file_state != "broken" && Account.site_admin.feature_enabled?(:word_count_in_speed_grader)
      delay(singleton: "attachment_set_word_count_#{global_id}").update_word_count
    end
  end

  def update_word_count
    update_column(:word_count, calculate_words)
  end

  def infer_root_account_id
    # see note in infer_namespace below
    splits = namespace.try(:split, /_/)
    return nil if splits.blank?

    if splits[1] == "localstorage"
      splits[3].to_i
    else
      splits[1].to_i
    end
  end

  def root_account
    root_account_id && Account.find_cached(root_account_id)
  rescue ::Canvas::AccountCacheError
    nil
  end

  def namespace
    read_attribute(:namespace) || (new_record? ? write_attribute(:namespace, infer_namespace) : nil)
  end

  def infer_namespace
    shard.activate do
      # If you are thinking about changing the format of this, take note: some
      # code relies on the namespace as a hacky way to efficiently get the
      # attachment's account id. Look for anybody who is accessing namespace and
      # splitting the string, etc.
      #
      # The infer_root_account_id accessor is still present above, but I didn't verify there
      # isn't any code still accessing the namespace for the account id directly. d
      ns = root_attachment.try(:namespace) if root_attachment_id
      ns ||= Attachment.current_namespace
      ns ||= context.root_account.file_namespace rescue nil
      ns ||= context.account.file_namespace rescue nil
      if Rails.env.development? && Attachment.local_storage?
        ns ||= ""
        ns = "_localstorage_/#{ns}" unless ns.start_with?("_localstorage_/")
      end
      ns = nil if ns && ns.empty?
      ns
    end
  end

  def change_namespace(new_namespace)
    raise "change_namespace must be called on a root attachment" if root_attachment
    return if new_namespace == namespace

    old_full_filename = full_filename
    write_attribute(:namespace, new_namespace)

    store.change_namespace(old_full_filename)
    shard.activate do
      Attachment.where("id=? OR root_attachment_id=?", self, self).update_all(namespace: new_namespace)
    end
  end

  def process_s3_details!(details)
    unless workflow_state == "unattached_temporary"
      self.workflow_state = nil
      self.file_state = "available"
    end
    self.md5 = (details[:etag] || "").delete('"')
    self.content_type = details[:content_type]
    self.size = details[:content_length]

    shard.activate do
      if (existing_attachment = find_existing_attachment_for_md5)
        if existing_attachment.s3object.exists?
          # deduplicate. the existing attachment's s3object should be the same as
          # that just uploaded ('cuz md5 match). delete the new copy and just
          # have this attachment inherit from the existing attachment.
          s3object.delete rescue nil
          self.root_attachment = existing_attachment
          write_attribute(:filename, nil)
        else
          # it looks like we had a duplicate, but the existing attachment doesn't
          # actually have an s3object (probably from an earlier bug). update it
          # and all its inheritors to inherit instead from this attachment.
          existing_attachment.root_attachment = self
          existing_attachment.write_attribute(:filename, nil)
          existing_attachment.save!
          Attachment.where(root_attachment_id: existing_attachment).update_all(
            root_attachment_id: id,
            filename: nil,
            updated_at: Time.zone.now
          )
        end
      end
      save!
      # normally this would be called by attachment_fu after it had uploaded the file to S3.
      run_after_attachment_saved
    end
  end

  CONTENT_LENGTH_RANGE = 10.gigabytes
  S3_EXPIRATION_TIME = 30.minutes

  def ajax_upload_params(local_upload_url, s3_success_url, options = {})
    # Build the data that will be needed for the user to upload to s3
    # without us being the middle-man
    sanitized_filename = full_filename.tr("+", " ")
    policy = {
      "expiration" => (options[:expiration] || S3_EXPIRATION_TIME).from_now.utc.iso8601,
      "conditions" => [
        { "key" => sanitized_filename },
        { "acl" => "private" },
        ["starts-with", "$Filename", ""],
        ["content-length-range", 1, (options[:max_size] || CONTENT_LENGTH_RANGE)]
      ]
    }

    # We don't use a Aws::S3::PresignedPost object to build this for us because
    # there is no way to add custom parameters to the condition, like we do
    # with `extras` below.
    options[:datetime] = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
    res = store.initialize_ajax_upload_params(local_upload_url, s3_success_url, options)
    policy = store.amend_policy_conditions(policy, datetime: options[:datetime])

    if res[:upload_params]["folder"].present?
      policy["conditions"] << ["starts-with", "$folder", ""]
    end

    extras = []
    if options[:no_redirect]
      extras << { "success_action_status" => "201" }
      extras << { "success_url" => res[:success_url] }
    elsif res[:success_url]
      extras << { "success_action_redirect" => res[:success_url] }
    end
    if content_type && content_type != "unknown/unknown"
      extras << { "content-type" => content_type }
    elsif options[:default_content_type]
      extras << { "content-type" => options[:default_content_type] }
    end
    policy["conditions"] += extras

    policy_encoded = Base64.encode64(policy.to_json).delete("\n")
    sig_key, sig_val = store.sign_policy(policy_encoded, options[:datetime])

    res[:id] = id
    res[:upload_params].merge!({
                                 "Filename" => filename,
                                 "key" => sanitized_filename,
                                 "acl" => "private",
                                 "Policy" => policy_encoded,
                                 sig_key => sig_val
                               })
    extras.map(&:to_a).each { |extra| res[:upload_params][extra.first.first] = extra.first.last }
    res
  end

  def self.decode_policy(policy_str, signature_str)
    return nil if policy_str.blank? || signature_str.blank?

    signature = Base64.decode64(signature_str)
    return nil if OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha1"), shared_secret, policy_str) != signature

    policy = JSON.parse(Base64.decode64(policy_str))
    return nil unless Time.zone.parse(policy["expiration"]) >= Time.now

    attachment = Attachment.find(policy["attachment_id"])
    return nil unless [:unattached, :unattached_temporary].include?(attachment.try(:state))

    [policy, attachment]
  end

  def unencoded_filename
    CGI.unescape(filename || t(:default_filename, "File"))
  end

  def quota_exemption_key
    assign_uuid
    Canvas::Security.hmac_sha1(uuid + "quota_exempt")[0, 10]
  end

  def verify_quota_exemption_key(hmac)
    Canvas::Security.verify_hmac_sha1(hmac, uuid + "quota_exempt", truncate: 10)
  end

  def self.minimum_size_for_quota
    Setting.get("attachment_minimum_size_for_quota", "512").to_i
  end

  def self.get_quota(context)
    quota = 0
    quota_used = 0
    context = context.quota_context if context.respond_to?(:quota_context) && context.quota_context
    if context
      GuardRail.activate(:secondary) do
        context.shard.activate do
          quota = Setting.get("context_default_quota", 50.megabytes.to_s).to_i
          quota = context.quota if context.respond_to?("quota") && context.quota

          attachment_scope = context.attachments.active.where(root_attachment_id: nil)

          if context.is_a?(User) || context.is_a?(Group)
            excluded_attachment_ids = []
            if context.is_a?(User)
              excluded_attachment_ids += context.attachments.joins(:attachment_associations).where(attachment_associations: { context_type: "Submission" }).pluck(:id)
            end
            excluded_attachment_ids += context.attachments.where(folder_id: context.submissions_folders).pluck(:id)
            attachment_scope = attachment_scope.where.not(id: excluded_attachment_ids) if excluded_attachment_ids.any?
          end

          min = minimum_size_for_quota
          # translated to ruby this is [size, min].max || 0
          quota_used = attachment_scope.sum("COALESCE(CASE when size < #{min} THEN #{min} ELSE size END, 0)").to_i
        end
      end
    end
    { quota: quota, quota_used: quota_used }
  end

  # Returns a boolean indicating whether the given context is over quota
  # If additional_quota > 0, that'll be added to the current quota used
  # (for example, to check if a new attachment of size additional_quota would
  # put the context over quota.)
  def self.over_quota?(context, additional_quota = nil)
    quota = get_quota(context)
    quota[:quota] < quota[:quota_used] + (additional_quota || 0)
  end

  def self.quota_available(context)
    quota = get_quota(context)
    [0, quota[:quota] - quota[:quota_used]].max
  end

  def handle_duplicates(method, opts = {})
    return [] unless method.present? && folder

    method = if folder.for_submissions?
               :rename
             else
               method.to_sym
             end

    if method == :overwrite
      atts = shard.activate { folder.active_file_attachments.where("display_name=? AND id<>?", self.display_name, id).to_a }
      method = :rename if atts.any? { |att| att.editing_restricted?(:any) }
    end

    deleted_attachments = []
    if method == :rename
      begin
        save! unless id

        valid_name = false
        shard.activate do
          iter_count = 1
          until valid_name
            existing_names = folder.active_file_attachments.where.not(id: id).pluck(:display_name)
            new_name = opts[:name] || self.display_name
            self.display_name = Attachment.make_unique_filename(new_name, existing_names, iter_count)

            if Attachment.where("id = ? AND NOT EXISTS (?)", self,
                                Attachment.where("id <> ? AND display_name = ? AND folder_id = ? AND file_state <> ?",
                                                 self, display_name, folder_id, "deleted"))
                         .limit(1)
                         .update_all(display_name: display_name) > 0
              valid_name = true
            end
            iter_count += 1
            raise UniqueRenameFailure if iter_count >= 10
          end
        end
      rescue UniqueRenameFailure => e
        Canvas::Errors.capture_exception(:attachment, e, :warn)
        # Failed to uniquely rename attachment, slapping on a UUID and moving on
        self.display_name = self.display_name + SecureRandom.uuid
        Attachment.where(id: self).limit(1).update_all(display_name: display_name)
      end
    elsif method == :overwrite && atts.any?
      shard.activate do
        Attachment.where(id: atts).update_all(replacement_attachment_id: id) # so we can find the new file in content links
        copy_access_attributes!(atts)
        atts.each do |a|
          # update content tags to refer to the new file
          if ContentTag.where(content_id: a, content_type: "Attachment").update_all(content_id: id, updated_at: Time.now.utc) > 0
            ContextModule.where(id: ContentTag.where(content_id: id, content_type: "Attachment").select(:context_module_id)).touch_all
          end
          # update replacement pointers pointing at the overwritten file
          context.attachments.where(replacement_attachment_id: a).update_all(replacement_attachment_id: id)
          # delete the overwritten file (unless the caller is queueing them up)
          a.destroy unless opts[:caller_will_destroy]
          deleted_attachments << a
        end
      end
    end
    deleted_attachments
  end

  def copy_access_attributes!(source_attachments)
    self.could_be_locked = true if source_attachments.any?(&:could_be_locked?)
    source = source_attachments.first
    self.file_state = "hidden" if source.file_state == "hidden"
    self.locked = source.locked
    self.unlock_at = source.unlock_at
    self.lock_at = source.lock_at
    self.usage_rights_id = source.usage_rights_id
    save! if changed?
  end

  def self.destroy_files(ids)
    Attachment.where(id: ids).each(&:destroy)
  end

  before_save :assign_uuid
  def assign_uuid
    self.uuid ||= CanvasSlug.generate_securish_uuid
  end
  protected :assign_uuid

  def reset_uuid!
    self.uuid = CanvasSlug.generate_securish_uuid
    save!
  end

  def inline_content?
    self.content_type.start_with?("text") || extension == ".html" || extension == ".htm" || extension == ".swf"
  end

  def self.shared_secret
    raise "Cannot call Attachment.shared_secret when configured for s3 storage" if s3_storage?

    "local_storage" + Canvas::Security.encryption_key
  end

  delegate :shared_secret, to: :store

  def instfs_hosted?
    !!instfs_uuid
  end

  def downloadable?
    instfs_hosted? || !!(authenticated_s3_url rescue false)
  end

  def public_url(**options)
    if instfs_hosted?
      InstFS.authenticated_url(self, options.merge(user: nil))
    else
      should_download = options.delete(:download)
      disposition = should_download ? "attachment" : "inline"
      options[:response_content_disposition] = "#{disposition}; #{disposition_filename}"
      authenticated_s3_url(**options)
    end
  end

  def public_inline_url(ttl = url_ttl)
    public_url(expires_in: ttl, download: false)
  end

  def public_download_url(ttl = url_ttl)
    public_url(expires_in: ttl, download: true)
  end

  def url_ttl
    setting = root_account&.settings&.[](:s3_url_ttl_seconds)
    setting ||= Setting.get("attachment_url_ttl", 1.hour.to_s)
    setting.to_i.seconds
  end

  def stored_locally?
    # if the file exists in inst-fs, it won't be in local storage even if
    # that's what Canvas otherwise thinks it's configured for
    return false if instfs_hosted?

    Attachment.local_storage?
  end

  def can_be_proxied?
    (mime_class == "html" && size < Setting.get("max_inline_html_proxy_size", 128 * 1024).to_i) ||
      (mime_class == "flash" && size < Setting.get("max_swf_proxy_size", 1024 * 1024).to_i) ||
      (content_type == "text/css" && size < Setting.get("max_css_proxy_size", 64 * 1024).to_i)
  end

  def local_storage_path
    "#{HostUrl.context_host(context)}/#{context_type.underscore.pluralize}/#{context_id}/files/#{id}/download?verifier=#{uuid}"
  end

  def content_type_with_encoding
    encoding.blank? ? content_type : "#{content_type}; charset=#{encoding}"
  end

  def content_type_with_text_match
    # treats all text/X files as text/plain (except text/html)
    (content_type.to_s.match(%r{^text/.*}) && content_type.to_s != "text/html") ? "text/plain" : content_type
  end

  # Returns an IO-like object containing the contents of the attachment file.
  # Any resources are guaranteed to be cleaned up when the object is garbage
  # collected (for instance, using the Tempfile class). Calling close on the
  # object may clean up things faster.
  #
  # By default, this method will stream the file as it is read, if it's stored
  # remotely and streaming is possible.  If opts[:need_local_file] is true,
  # then a local Tempfile will be created if necessary and the IO object
  # returned will always respond_to :path and :rewind, and have the right file
  # extension.
  #
  # Be warned! If local storage is used, a File handle to the actual file will
  # be returned, not a Tempfile handle. So don't rm the file's .path or
  # anything crazy like that. If you need to test whether you can move the file
  # at .path, or if you need to copy it, check if the file is_a?(Tempfile) (and
  # pass :need_local_file => true of course).
  #
  # If opts[:temp_folder] is given, and a local temporary file is created, this
  # path will be used instead of the default system temporary path. It'll be
  # created if necessary.
  def open(opts = {}, &block)
    if instfs_hosted?
      if block
        streaming_download(&block)
      else
        create_tempfile(opts) do |tempfile|
          streaming_download(tempfile)
        end
      end
    else
      store.open(opts, &block)
    end
  end

  class FailedResponse < StandardError; end
  # GETs this attachment's public_url and streams the response to the
  # passed block; this is a helper function for #open
  # (you should call #open instead of this)
  private def streaming_download(dest = nil, &block)
    retries ||= 0
    CanvasHttp.get(public_url) do |response|
      raise FailedResponse, "Expected 200, got #{response.code}: #{response.body}" unless response.code.to_i == 200

      response.read_body(dest, &block)
    end
  rescue FailedResponse, Net::ReadTimeout, Net::OpenTimeout => e
    if (retries += 1) < Setting.get(:streaming_download_retries, "5").to_i
      Canvas::Errors.capture_exception(:attachment, e, :info)
      retry
    else
      raise e
    end
  end

  def create_tempfile(opts)
    if opts[:temp_folder].present? && !File.exist?(opts[:temp_folder])
      FileUtils.mkdir_p(opts[:temp_folder])
    end
    tempfile = Tempfile.new(["attachment_#{id}", extension],
                            opts[:temp_folder].presence || Dir.tmpdir)
    tempfile.binmode
    yield tempfile
    tempfile.rewind
    tempfile
  end

  def has_thumbnail?
    thumbnailable? && (instfs_hosted? || thumbnail.present?)
  end

  # you should be able to pass an optional width, height, and page_number/video_seconds to this method for media objects
  # you should be able to pass an optional size (e.g. '64x64') to this method for other thumbnailable content types
  #
  # direct use of this method is deprecated. use the controller's
  # `file_authenticator.thumbnail_url(attachment)` instead.
  def thumbnail_url(options = {})
    return nil if Attachment.skip_thumbnails

    geometry = options[:size]
    if thumbnail || geometry.present?
      to_use = thumbnail_for_size(geometry) || thumbnail
      to_use.cached_s3_url
    elsif media_object&.media_id
      CanvasKaltura::ClientV3.new.thumbnail_url(media_object.media_id,
                                                width: options[:width] || 140,
                                                height: options[:height] || 100,
                                                vid_sec: options[:video_seconds] || 5)
    else
      nil # "still need to handle things that are not images with thumbnails or kaltura docs"
    end
  end

  def thumbnail_for_size(geometry)
    if self.class.allows_thumbnails_of_size?(geometry)
      to_use = thumbnails.loaded? ? thumbnails.detect { |t| t.thumbnail == geometry } : thumbnails.where(thumbnail: geometry).first
      to_use || create_dynamic_thumbnail(geometry)
    end
  end

  def self.allows_thumbnails_of_size?(geometry)
    dynamic_thumbnail_sizes.include?(geometry)
  end

  def self.truncate_filename(filename, max_len, &block)
    block ||= ->(str, len) { str[0...len] }
    ext_index = filename.rindex(".")
    if ext_index
      ext = block.call(filename[ext_index..], (max_len / 2) + 1)
      base = block.call(filename[0...ext_index], max_len - ext.length)
      base + ext
    else
      block.call(filename, max_len)
    end
  end

  def save_without_broadcasting
    @skip_broadcasts = true
    save
  ensure
    @skip_broadcasts = false
  end

  def save_without_broadcasting!
    @skip_broadcasts = true
    save!
  ensure
    @skip_broadcasts = false
  end

  # called before save
  # notification is not sent until file becomes 'available'
  # (i.e., don't notify before it finishes uploading)
  def set_need_notify
    self.need_notify = true if !@skip_broadcasts &&
                               file_state_changed? &&
                               file_state == "available" &&
                               context.respond_to?(:state) && context.state == :available &&
                               folder && folder.visible?
  end

  def notify_only_admins?
    context.is_a?(Course) && (folder.currently_locked? || currently_locked? || context.tab_hidden?(Course::TAB_FILES))
  end

  # generate notifications for recent file operations
  # (this should be run in a delayed job)
  def self.do_notifications
    # consider a batch complete when no uploads happen in this time
    quiet_period = Setting.get("attachment_notify_quiet_period_minutes", "5").to_i.minutes.ago

    # if a batch is older than this, just drop it rather than notifying
    discard_older_than = Setting.get("attachment_notify_discard_older_than_hours", "120").to_i.hours.ago

    while true
      file_batches = Attachment
                     .where("need_notify")
                     .group(:context_id, :context_type)
                     .having("MAX(updated_at)<?", quiet_period)
                     .limit(500)
                     .pluck(Arel.sql("COUNT(attachments.id), MIN(attachments.id), MAX(updated_at), context_id, context_type"))
      break if file_batches.empty?

      file_batches.each do |count, attachment_id, last_updated_at, context_id, context_type|
        # clear the need_notify flag for this batch
        Attachment.where("need_notify AND updated_at <= ? AND context_id = ? AND context_type = ?", last_updated_at, context_id, context_type)
                  .update_all(need_notify: nil)

        # skip the notification if this batch is too old to be timely
        next if last_updated_at.to_time < discard_older_than

        # now generate the notification
        record = Attachment.find(attachment_id)
        next if record.context.is_a?(Course) && (!record.context.available? || record.context.concluded?)

        if record.notify_only_admins?
          # only notify course students if they are able to access it
          to_list = record.context.participating_admins - [record.user]
        elsif record.context.respond_to?(:participants)
          to_list = record.context.participants(by_date: true) - [record.user]
        end
        recipient_keys = (to_list || []).compact.map(&:asset_string)
        next if recipient_keys.empty?

        notification = BroadcastPolicy.notification_finder.by_name(count.to_i > 1 ? "New Files Added" : "New File Added")
        data = { count: count }
        DelayedNotification.delay_if_production(priority: 30).process(record, notification, recipient_keys, data)
      end
    end
  end

  def infer_display_name
    self.display_name ||= unencoded_filename
  end
  protected :infer_display_name

  def readable_size
    ActiveSupport::NumberHelper.number_to_human_size(size) rescue "size unknown"
  end

  def disposition_filename
    ascii_filename = I18n.transliterate(display_name, replacement: "_")

    # response-content-disposition will be url encoded in the depths of
    # aws-s3, doesn't need to happen here. we'll be nice and ghetto http
    # quote the filename string, though.
    quoted_ascii = ascii_filename.gsub(/([\x00-\x1f"\x7f])/, "\\\\\\1")

    # awesome browsers will use the filename* and get the proper unicode filename,
    # everyone else will get the sanitized ascii version of the filename
    quoted_unicode = "UTF-8''#{URI.escape(display_name, /[^A-Za-z0-9.]/)}"
    %(filename="#{quoted_ascii}"; filename*=#{quoted_unicode})
  end
  protected :disposition_filename

  def attachment_path_id
    a = (respond_to?(:root_attachment) && root_attachment) || self
    ((a.respond_to?(:parent_id) && a.parent_id) || a.id).to_s
  end

  def filename
    read_attribute(:filename) || root_attachment&.filename
  end

  def filename=(name)
    # infer a display name without round-tripping through truncated CGI-escaped filename
    # (which reduces the length of unicode filenames to as few as 28 characters)
    self.display_name ||= Attachment.truncate_filename(name, 255)
    super(name)
  end

  def thumbnail
    super || root_attachment.try(:thumbnail)
  end

  def content_directory
    directory_name || Folder.root_folders(context).first.name
  end

  def to_atom(opts = {})
    Atom::Entry.new do |entry|
      entry.title     = t(:feed_title, "File: %{title}", title: context.name) unless opts[:include_context]
      entry.title     = t(:feed_title_with_context, "File, %{course_or_group}: %{title}", course_or_group: context.name, title: context.name) if opts[:include_context]
      entry.authors << Atom::Person.new(name: context.name)
      entry.updated   = updated_at
      entry.published = created_at
      entry.id        = "tag:#{HostUrl.default_host},#{created_at.strftime("%Y-%m-%d")}:/files/#{feed_code}"
      entry.links << Atom::Link.new(rel: "alternate",
                                    href: "http://#{HostUrl.context_host(context)}/#{context_url_prefix}/files/#{id}")
      entry.content = Atom::Content::Html.new(self.display_name.to_s)
    end
  end

  def name
    display_name
  end

  def title
    display_name
  end

  def associate_with(context)
    attachment_associations.create(context: context)
  end

  def mime_class
    # NOTE: keep this list in sync with what's in packages/canvas-rce/src/common/mimeClass.js
    {
      "text/html" => "html",
      "text/x-csharp" => "code",
      "text/xml" => "code",
      "text/css" => "code",
      "text" => "text",
      "text/plain" => "text",
      "application/rtf" => "doc",
      "text/rtf" => "doc",
      "application/vnd.oasis.opendocument.text" => "doc",
      "application/pdf" => "pdf",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "doc",
      "application/x-docx" => "doc",
      "application/msword" => "doc",
      "application/vnd.ms-powerpoint" => "ppt",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" => "ppt",
      "application/vnd.ms-excel" => "xls",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "xls",
      "application/vnd.oasis.opendocument.spreadsheet" => "xls",
      "image/jpeg" => "image",
      "image/pjpeg" => "image",
      "image/png" => "image",
      "image/gif" => "image",
      "image/bmp" => "image",
      "image/svg+xml" => "image",
      "image/webp" => "image",
      "image/vnd.microsoft.icon" => "image",
      "application/x-rar" => "zip",
      "application/x-rar-compressed" => "zip",
      "application/x-zip" => "zip",
      "application/x-zip-compressed" => "zip",
      "application/xml" => "code",
      "application/zip" => "zip",
      "audio/mpeg" => "audio",
      "audio/mp3" => "audio",
      "audio/basic" => "audio",
      "audio/mid" => "audio",
      "audio/3gpp" => "audio",
      "audio/x-aiff" => "audio",
      "audio/x-mpegurl" => "audio",
      "audio/x-ms-wma" => "audio",
      "audio/x-pn-realaudio" => "audio",
      "audio/x-wav" => "audio",
      "audio/mp4" => "audio",
      "audio/wav" => "audio",
      "audio/webm" => "audio",
      "video/mpeg" => "video",
      "video/quicktime" => "video",
      "video/x-la-asf" => "video",
      "video/x-ms-asf" => "video",
      "video/x-ms-wma" => "video",
      "video/x-ms-wmv" => "audio",
      "video/x-msvideo" => "video",
      "video/x-sgi-movie" => "video",
      "video/3gpp" => "video",
      "video/mp4" => "video",
      :"video/webm" => "video",
      :"video/avi" => "video",
      "application/x-shockwave-flash" => "flash"
    }[content_type] || "file"
  end

  def associated_with_submission?
    @associated_with_submission ||= attachment_associations.where(context_type: "Submission").exists?
  end

  def user_can_read_through_context?(user, session)
    context&.grants_right?(user, session, :read) ||
      (context.is_a?(AssessmentQuestion) && context.user_can_see_through_quiz_question?(user, session))
  end

  set_policy do
    given do |user, session|
      context&.grants_right?(user, session, :manage_files_edit) &&
        !associated_with_submission? &&
        (!folder || folder.grants_right?(user, session, :manage_contents))
    end
    can :read and can :update

    given do |user, session|
      context&.grants_right?(user, session, :manage_files_delete) &&
        !associated_with_submission? &&
        (!folder || folder.grants_right?(user, session, :manage_contents))
    end
    can :read and can :delete

    given do |user, session|
      context&.grants_right?(user, session, :manage_files_add)
    end
    can :read and can :create and can :download and can :read_as_admin

    given { public? }
    can :read and can :download

    given { |user, session| context&.grants_right?(user, session, :read) } # students.include? user }
    can :read

    given { |user, session| context&.grants_right?(user, session, :read_as_admin) }
    can :read_as_admin

    given do |user, session|
      user_can_read_through_context?(user, session) && !locked_for?(user, check_policies: true)
    end
    can :read and can :download

    given do |_user, session|
      (u = session.try(:file_access_user)) &&
        (user_can_read_through_context?(u, session) ||
          (context.respond_to?(:is_public_to_auth_users?) && context.is_public_to_auth_users?)) &&
        session["file_access_expiration"] && session["file_access_expiration"].to_i > Time.zone.now.to_i
    end
    can :read

    given do |_user, session|
      (u = session.try(:file_access_user)) &&
        (user_can_read_through_context?(u, session) ||
          (context.respond_to?(:is_public_to_auth_users?) && context.is_public_to_auth_users?)) &&
        !locked_for?(u, check_policies: true) &&
        session["file_access_expiration"] && session["file_access_expiration"].to_i > Time.zone.now.to_i
    end
    can :download

    given do |user|
      owner = self.user
      context_type == "Assignment" && user == owner
    end
    can :attach_to_submission_comment
  end

  def clear_permissions(run_at)
    GuardRail.activate(:primary) do
      delay(run_at: run_at,
            singleton: "clear_attachment_permissions_#{global_id}").touch
    end
  end

  def next_lock_change
    [lock_at, unlock_at].compact.select { |t| t > Time.zone.now }.min
  end

  def locked_for?(user, opts = {})
    return false if opts[:check_policies] && grants_right?(user, :read_as_admin)
    return { asset_string: asset_string, manually_locked: true } if locked || Folder.is_locked?(self.folder_id)

    RequestCache.cache(locked_request_cache_key(user)) do
      locked = false
      # prevent an access attempt shortly before unlock_at/lock_at from caching permissions beyond that time
      next_clear_cache = next_lock_change
      if next_clear_cache.present? && next_clear_cache < (Time.zone.now + AdheresToPolicy::Cache::CACHE_EXPIRES_IN)
        clear_permissions(next_clear_cache)
      end
      if unlock_at && Time.zone.now < unlock_at
        locked = { asset_string: asset_string, unlock_at: unlock_at }
      elsif lock_at && Time.now > lock_at
        locked = { asset_string: asset_string, lock_at: lock_at }
      elsif could_be_locked && (item = locked_by_module_item?(user, opts))
        locked = { asset_string: asset_string, context_module: item.context_module.attributes }
        locked[:unlock_at] = locked[:context_module]["unlock_at"] if locked[:context_module]["unlock_at"] && locked[:context_module]["unlock_at"] > Time.now.utc
      end
      locked
    end
  end

  def hidden?
    return @hidden if defined?(@hidden)

    @hidden = self.file_state == "hidden" || folder&.hidden?
  end

  def published?
    !locked?
  end

  def publish!
    self.locked = false
    save!
  end

  def just_hide
    self.file_state == "hidden"
  end

  def public?
    self.file_state == "public"
  end

  def currently_locked
    locked || (lock_at && Time.zone.now > lock_at) || (unlock_at && Time.zone.now < unlock_at) || self.file_state == "hidden"
  end
  alias_method :currently_locked?, :currently_locked

  def hidden
    hidden?
  end

  def hidden=(val)
    self.file_state = (val == true || val == "1" ? "hidden" : "available")
  end

  def context_module_action(user, action)
    context_module_tags.each { |tag| tag.context_module_action(user, action) }
  end

  include Workflow

  # Right now, using the state machine to manage whether an attachment has
  # been uploaded or scrubbed in other ways.  All that work should be managed by
  # the state machine.
  workflow do
    state :pending_upload do
      event :upload, transitions_to: :processing
      event :process, transitions_to: :processed
      event :mark_errored, transitions_to: :errored
    end

    state :processing do
      event :process, transitions_to: :processed
      event :mark_errored, transitions_to: :errored
    end

    state :processed do
      event :recycle, transitions_to: :pending_upload
    end
    state :errored do
      event :recycle, transitions_to: :pending_upload
    end
    state :deleted
    state :to_be_zipped
    state :zipping
    state :zipped
    state :unattached
    state :unattached_temporary
  end

  scope :visible, -> { where(["attachments.file_state in (?, ?)", "available", "public"]) }
  scope :not_deleted, -> { where("attachments.file_state<>'deleted'") }

  scope :not_hidden, -> { where("attachments.file_state<>'hidden'") }
  scope :uncategorized, -> { where(category: UNCATEGORIZED) }
  scope :for_category, ->(category) { where(category: category) }
  scope :not_locked, lambda {
    where("attachments.locked IS NOT TRUE
      AND (attachments.lock_at IS NULL OR attachments.lock_at>?)
      AND (attachments.unlock_at IS NULL OR attachments.unlock_at<?)", Time.now.utc, Time.now.utc)
  }

  scope :by_content_types, lambda { |types|
    condition_sql = build_content_types_sql(types)
    where(condition_sql)
  }

  scope :by_exclude_content_types, lambda { |types|
    condition_sql = build_content_types_sql(types)
    where.not(condition_sql)
  }

  def self.build_content_types_sql(types)
    clauses = []
    types.each do |type|
      clauses << if type.include? "/"
                   sanitize_sql_array(["(attachments.content_type=?)", type])
                 else
                   wildcard("attachments.content_type", type + "/", type: :right)
                 end
    end
    clauses.join(" OR ")
  end

  # this method is used to create attachments from file uploads that are just
  # data files. Used in multiple importers in canvas.
  def self.create_data_attachment(context, data, display_name = nil)
    context.shard.activate do
      Attachment.new.tap do |att|
        Attachment.skip_3rd_party_submits(true)
        att.context = context
        att.display_name = display_name if display_name
        Attachments::Storage.store_for_attachment(att, data)
        att.save!
      end
    end
  ensure
    Attachment.skip_3rd_party_submits(false)
  end

  alias_method :destroy_permanently!, :destroy
  # file_state is like workflow_state, which was already taken
  # possible values are: available, deleted
  def destroy
    return if new_record?

    self.file_state = "deleted" # destroy
    self.deleted_at = Time.now.utc
    ContentTag.delete_for(self)
    MediaObject.where(attachment_id: id).update_all(attachment_id: nil, updated_at: Time.now.utc)
    save!
    # if the attachment being deleted belongs to a user and the uuid (hash of file) matches the avatar_image_url
    # then clear the avatar_image_url value.
    context.clear_avatar_image_url_with_uuid(self.uuid) if context_type == "User" && self.uuid.present?
    true
  end

  # this will delete the content of the attachment but not delete the attachment
  # object. It will replace the attachment content with a file_removed file.
  def destroy_content_and_replace(deleted_by_user = nil)
    shard.activate do
      att = root_attachment_id? ? root_attachment : self
      return true if Purgatory.where(attachment_id: att).active.exists?

      att.send_to_purgatory(deleted_by_user)
      att.destroy_content
      att.thumbnail&.destroy

      file_removed_path = self.class.file_removed_path
      new_name = File.basename(file_removed_path)

      if att.instfs_hosted? && InstFS.enabled?
        # dupliciate the base file_removed file to a unique uuid
        att.instfs_uuid = InstFS.duplicate_file(self.class.file_removed_base_instfs_uuid)
      else
        Attachments::Storage.store_for_attachment(att, File.open(file_removed_path))
      end
      att.filename = new_name
      att.display_name = new_name
      att.content_type = "application/pdf"
      CrocodocDocument.where(attachment_id: att.children_and_self.select(:id)).delete_all
      canvadoc_scope = Canvadoc.where(attachment_id: att.children_and_self.select(:id))
      CanvadocsSubmission.where(canvadoc_id: canvadoc_scope.select(:id)).delete_all
      AnonymousOrModerationEvent.where(canvadoc_id: canvadoc_scope.select(:id)).delete_all
      canvadoc_scope.delete_all
      att.save!
    end
  end

  def self.file_removed_path
    Rails.root.join("public/file_removed/file_removed.pdf")
  end

  # find the file_removed file on instfs (or upload it)
  def self.file_removed_base_instfs_uuid
    # i imagine that inevitably someone is going to change the file without knowing about any of this
    # so make the cache depend on the file contents
    path = file_removed_path
    @@file_removed_md5 ||= Digest::MD5.hexdigest(File.read(path))
    key = "file_removed_instfs_uuid_#{@@file_removed_md5}_#{Digest::MD5.hexdigest(InstFS.app_host)}"

    @@base_file_removed_uuids ||= {}
    @@base_file_removed_uuids[key] ||= Rails.cache.fetch(key) do
      # re-upload and save the uuid - it's okay if we end up repeating this every now and then
      # it's at least an improvement over re-uploading the file _every time_ we replace
      InstFS.direct_upload(
        file_object: File.open(path),
        file_name: File.basename(path)
      )
    end
  end

  # this method does not destroy anything. It copies the content to a new s3object
  def send_to_purgatory(deleted_by_user = nil)
    make_rootless
    new_instfs_uuid = nil
    if Attachment.s3_storage? && s3object.exists?
      s3object.copy_to(bucket.object(purgatory_filename))
    elsif instfs_hosted? && InstFS.enabled?
      # copy to a new instfs file
      new_instfs_uuid = InstFS.duplicate_file(instfs_uuid)
    elsif Attachment.local_storage?
      FileUtils.mkdir(local_purgatory_directory) unless File.exist?(local_purgatory_directory)
      FileUtils.cp full_filename, local_purgatory_file
    end
    if Purgatory.where(attachment_id: self).exists?
      p = Purgatory.where(attachment_id: self).take
      p.deleted_by_user = deleted_by_user
      p.old_filename = filename
      p.old_display_name = display_name
      p.old_content_type = content_type
      p.new_instfs_uuid = new_instfs_uuid
      p.workflow_state = "active"
      p.save!
    else
      Purgatory.create!(attachment: self, old_filename: filename, old_display_name: display_name,
                        old_content_type: content_type, new_instfs_uuid: new_instfs_uuid, deleted_by_user: deleted_by_user)
    end
  end

  def purgatory_filename
    File.join("purgatory", global_id.to_s)
  end

  def local_purgatory_file
    File.join(local_purgatory_directory, global_id.to_s)
  end

  def local_purgatory_directory
    Rails.root.join(attachment_options[:path_prefix].to_s, "purgatory")
  end

  def resurrect_from_purgatory
    p = Purgatory.where(attachment_id: id).take
    raise "must have been sent to purgatory first" unless p
    raise "purgatory record has expired" if p.workflow_state == "expired"

    write_attribute(:filename, p.old_filename)
    write_attribute(:display_name, p.old_display_name)
    write_attribute(:content_type, p.old_content_type)
    write_attribute(:root_attachment_id, nil)

    if InstFS.enabled?
      if p.new_instfs_uuid
        # just set it to the copied uuid, shouldn't get deleted when expired since we'll set p to 'restored'
        write_attribute(:instfs_uuid, p.new_instfs_uuid)
      else
        raise "purgatory record was created before being fixed for inst-fs"
      end
    elsif Attachment.s3_storage?
      old_s3object = bucket.object(purgatory_filename)
      raise Attachment::FileDoesNotExist unless old_s3object.exists?

      old_s3object.copy_to(bucket.object(full_filename))
    else
      raise Attachment::FileDoesNotExist unless File.exist?(local_purgatory_file)

      FileUtils.mv local_purgatory_file, full_filename
    end
    save! if changed?
    p.workflow_state = "restored"
    p.save!
  end

  def dmca_file_removal
    destroy_content_and_replace
  end

  def destroy_content
    raise "must be a root_attachment" if root_attachment_id
    return unless filename

    if instfs_hosted?
      InstFS.delete_file(instfs_uuid)
      self.instfs_uuid = nil
    elsif Attachment.s3_storage?
      s3object.delete unless ApplicationController.test_cluster?
    else
      FileUtils.rm full_filename
    end
  end

  def destroy_permanently_plus
    unless root_attachment_id
      make_childless
      destroy_content
    end
    destroy_permanently!
  end

  def make_childless(preferred_child = nil)
    return if root_attachment_id

    child = preferred_child || children.take
    return unless child
    raise "must be a child" unless child.root_attachment_id == id

    child.root_attachment_id = nil
    copy_attachment_content(child)
    Attachment.where(root_attachment_id: self).where.not(id: child).update_all(root_attachment_id: child.id)
  end

  def copy_attachment_content(destination)
    # parent is broken; if child is probably broken too, make sure it gets marked as broken
    if file_state == "broken" && destination.md5.nil?
      Attachment.where(id: destination).update_all(file_state: "broken")
      return
    end

    destination.write_attribute(:filename, filename) if filename
    if Attachment.s3_storage?
      if filename && s3object.exists? && !destination.s3object.exists?
        s3object.copy_to(destination.s3object)
      end
    else
      return if destination.store.exists? && open == destination.open

      old_content_type = self.content_type
      scope = Attachment.where(md5: md5, namespace: namespace, root_attachment_id: nil)
      scope.update_all(content_type: "invalid/invalid") # prevents find_existing_attachment_for_md5 from reattaching the child to the old root

      # TODO: when RECNVS-323 is complete, branch here to call an inst-fs
      # copy method to avoid sending object when it is not necessary
      Attachments::Storage.store_for_attachment(destination, open)

      scope.where.not(id: destination).update_all(content_type: old_content_type)
    end
    destination.save!
  end

  def make_rootless
    return unless root_attachment_id

    root = root_attachment
    return unless root

    self.root_attachment_id = nil
    root.copy_attachment_content(self)
    run_after_attachment_saved
  end

  def restore
    self.file_state = "available"
    if save
      handle_duplicates(:rename)
    end
    true
  end

  def deleted?
    self.file_state == "deleted"
  end

  def available?
    self.file_state == "available"
  end

  def crocodocable?
    Canvas::Crocodoc.enabled? &&
      CrocodocDocument::MIME_TYPES.include?(content_type)
  end

  def canvadocable?
    for_assignment_or_submissions = folder&.for_submissions? || folder&.for_student_annotation_documents?
    canvadocable_mime_types = for_assignment_or_submissions ? Canvadoc.submission_mime_types : Canvadoc.mime_types
    Canvadocs.enabled? && canvadocable_mime_types.include?(content_type_with_text_match)
  end

  def self.submit_to_canvadocs(ids)
    Attachment.where(id: ids).find_each(&:submit_to_canvadocs)
  end

  def self.skip_3rd_party_submits(skip = true)
    @skip_3rd_party_submits = skip
  end

  def self.skip_3rd_party_submits?
    !!@skip_3rd_party_submits
  end

  def self.skip_media_object_creation
    @skip_media_object_creation = true
    yield
  ensure
    @skip_media_object_creation = false
  end

  def self.skip_media_object_creation?
    !!@skip_media_object_creation
  end

  def submit_to_canvadocs(attempt = 1, opts = {})
    # ... or crocodoc (this will go away soon)
    return if Attachment.skip_3rd_party_submits?

    submit_to_crocodoc_instead = opts[:wants_annotation] &&
                                 crocodocable? &&
                                 !Canvadocs.annotations_supported?
    if submit_to_crocodoc_instead
      # get crocodoc off the canvadocs strand
      # (maybe :wants_annotation was a dumb idea)
      delay(n_strand: "crocodoc",
            priority: Delayed::LOW_PRIORITY)
        .submit_to_crocodoc(attempt)
    elsif canvadocable?
      doc = canvadoc || create_canvadoc
      doc.upload({
                   annotatable: opts[:wants_annotation],
                   preferred_plugins: opts[:preferred_plugins]
                 })
      update_attribute(:workflow_state, "processing")
    end
  rescue => e
    warnable_errors = [
      Canvadocs::BadGateway,
      Canvadoc::UploadTimeout,
      Canvadocs::ServerError
    ]
    error_level = warnable_errors.any? { |kls| e.is_a?(kls) } ? :warn : :error
    update_attribute(:workflow_state, "errored")
    error_data = { type: :canvadocs, attachment_id: id, annotatable: opts[:wants_annotation] }
    Canvas::Errors.capture(e, error_data, error_level)

    if attempt <= Setting.get("max_canvadocs_attempts", "5").to_i
      delay(n_strand: "canvadocs_retries",
            run_at: (5 * attempt).minutes.from_now,
            priority: Delayed::LOW_PRIORITY).submit_to_canvadocs(attempt + 1, opts)
    end
  end

  def submit_to_crocodoc(attempt = 1)
    if crocodocable? && !Attachment.skip_3rd_party_submits?
      crocodoc = crocodoc_document || create_crocodoc_document
      crocodoc.upload
      update_attribute(:workflow_state, "processing")
    end
  rescue => e
    update_attribute(:workflow_state, "errored")
    Canvas::Errors.capture(e, type: :canvadocs, attachment_id: id)

    if attempt <= Setting.get("max_crocodoc_attempts", "5").to_i
      delay(n_strand: "crocodoc_retries",
            run_at: (5 * attempt).minutes.from_now,
            priority: Delayed::LOW_PRIORITY)
        .submit_to_crocodoc(attempt + 1)
    end
  end

  def self.mimetype(filename)
    res = nil
    res = File.mime_type?(filename) if !res || res == "unknown/unknown"
    res ||= "unknown/unknown"
    res
  end

  def mimetype(_filename = nil)
    res = Attachment.mimetype(filename) # use the object's filename, not the passed in filename
    res = File.mime_type?(uploaded_data) if (!res || res == "unknown/unknown") && uploaded_data
    res ||= "unknown/unknown"
    res
  end

  def folder_path
    if folder
      folder.full_name
    else
      Folder.root_folders(context).first.try(:name)
    end
  end

  def full_path
    "#{folder_path}/#{filename}"
  end

  def matches_full_path?(path)
    f_path = full_path
    f_path == path || URI.unescape(f_path) == path || f_path.casecmp?(path) || URI.unescape(f_path).casecmp?(path)
  rescue
    false
  end

  def full_display_path
    "#{folder_path}/#{display_name}"
  end

  def matches_full_display_path?(path)
    fd_path = full_display_path
    fd_path == path || URI.unescape(fd_path) == path || fd_path.casecmp?(path) || URI.unescape(fd_path).casecmp?(path)
  rescue
    false
  end

  def self.matches_name?(name, match)
    return false unless name

    name == match || URI.unescape(name) == match || name.casecmp?(match) || URI.unescape(name).casecmp?(match)
  rescue
    false
  end

  def self.attachment_list_from_migration(context, ids)
    return "" if !ids || !ids.is_a?(Array) || ids.empty?

    description = "<h3>#{ERB::Util.h(t("title.migration_list", "Associated Files"))}</h3><ul>"
    ids.each do |id|
      attachment = context.attachments.where(migration_id: id).first
      description += "<li><a href='/courses/#{context.id}/files/#{attachment.id}/download'>#{ERB::Util.h(attachment.display_name)}</a></li>" if attachment
    end
    description += "</ul>"
    description
  end

  def self.find_from_path(path, context)
    list = path.split("/").reject(&:empty?)
    if list[0] != Folder.root_folders(context).first.name
      list.unshift(Folder.root_folders(context).first.name)
    end
    filename = list.pop
    folder = context.folder_name_lookups[list.join("/")] rescue nil
    folder ||= context.folders.active.where(full_name: list.join("/")).first
    context.folder_name_lookups ||= {}
    context.folder_name_lookups[list.join("/")] = folder
    file = nil
    if folder
      file = folder.file_attachments.where(filename: filename).first
      file ||= folder.file_attachments.where(display_name: filename).first
    end
    file
  end

  def self.current_root_account=(account)
    # TODO: rename to @current_root_account
    @domain_namespace = account
  end

  def self.current_root_account
    @domain_namespace
  end

  def self.current_namespace
    @domain_namespace.respond_to?(:file_namespace) ? @domain_namespace.file_namespace : @domain_namespace
  end

  # deprecated
  def self.domain_namespace=(val)
    self.current_root_account = val
  end

  def self.domain_namespace
    current_namespace
  end

  def self.serialization_methods
    %i[mime_class currently_locked crocodoc_available?]
  end
  cattr_accessor :skip_thumbnails

  scope :uploadable, -> { where(workflow_state: "pending_upload") }
  scope :active, -> { where(file_state: "available") }
  scope :deleted, -> { where(file_state: "deleted") }
  scope :by_display_name, -> { order(display_name_order_by_clause("attachments")) }
  scope :by_position_then_display_name, -> { order(:position, display_name_order_by_clause("attachments")) }
  def self.serialization_excludes
    [:uuid, :namespace]
  end

  # returns filename, if it's already unique, or returns a modified version of
  # filename that makes it unique. you can either pass existing_files as string
  # filenames, in which case it'll test against those, or a block that'll be
  # called repeatedly with a filename until it returns true.
  def self.make_unique_filename(filename, existing_files = [], attempts = 1, &block)
    block ||= proc { |fname| !existing_files.include?(fname) }

    return filename if attempts <= 1 && block.call(filename)

    addition = attempts || 1
    dir = File.dirname(filename)
    dir = dir == "." ? "" : "#{dir}/"
    extname = filename[/(\.[A-Za-z][A-Za-z0-9]*)*(\.[A-Za-z0-9]*)$/] || ""
    basename = File.basename(filename, extname)

    random_backup_name = "#{dir}#{basename}-#{SecureRandom.uuid}#{extname}"
    return random_backup_name if attempts >= 8

    until block.call(new_name = "#{dir}#{basename}-#{addition}#{extname}")
      addition += 1
      return random_backup_name if addition >= 8
    end
    new_name
  end

  def self.shorten_filename(filename)
    return filename.truncate(175, omission: "...#{File.extname(filename)}") if filename.length > 180

    filename
  end

  # the list of thumbnail sizes to be pre-generated automatically
  def self.automatic_thumbnail_sizes
    attachment_options[:thumbnails].keys
  end

  def automatic_thumbnail_sizes
    if thumbnailable? && !instfs_hosted?
      self.class.automatic_thumbnail_sizes
    else
      []
    end
  end
  protected :automatic_thumbnail_sizes

  DYNAMIC_THUMBNAIL_SIZES = %w[640x>].freeze

  # the list of allowed thumbnail sizes to be generated dynamically
  def self.dynamic_thumbnail_sizes
    DYNAMIC_THUMBNAIL_SIZES + Setting.get("attachment_thumbnail_sizes", "").split(",")
  end

  def create_dynamic_thumbnail(geometry_string)
    tmp = create_temp_file
    Attachment.unique_constraint_retry do
      create_or_update_thumbnail(tmp, geometry_string, geometry_string)
    end
  end

  class OverQuotaError < StandardError; end

  class << self
    def clone_url_strand_overrides
      @clone_url_strand_overrides ||= YAML.safe_load(DynamicSettings.find(tree: :private)["clone_url_strand.yml"] || "{}")
    end

    def reset_clone_url_strand_overrides
      @clone_url_strand_overrides = nil
    end
    Canvas::Reloader.on_reload { Attachment.reset_clone_url_strand_overrides }

    def clone_url_strand(url)
      _, uri = CanvasHttp.validate_url(url) rescue nil
      return "file_download" unless uri&.host
      return ["file_download", clone_url_strand_overrides[uri.host]] if clone_url_strand_overrides[uri.host]

      first_dot = uri.host.rindex(".")
      second_dot = uri.host.rindex(".", first_dot - 1) if first_dot
      return ["file_download", uri.host] unless second_dot

      ["file_download", uri.host[second_dot + 1..]]
    end
  end

  def clone_url_error_info(error, url)
    {
      tags: {
        type: CLONING_ERROR_TYPE
      },
      extra: {
        http_status_code: error.try(:code),
        body: error.try(:body),
        url: url
      }.compact
    }
  end

  def clone_url(url, duplicate_handling, check_quota, opts = {})
    Attachment.clone_url_as_attachment(url, attachment: self)

    if check_quota
      save! # save to calculate attachment size, otherwise self.size is nil
      if Attachment.over_quota?(opts[:quota_context] || context, size)
        raise OverQuotaError, t(:over_quota, "The downloaded file exceeds the quota.")
      end
    end

    self.file_state = "available"
    save!

    # the UI only needs the id from here
    opts[:progress]&.set_results({ id: id })

    handle_duplicates(duplicate_handling || "overwrite")
    nil # the rescue returns true if the file failed and is retryable, nil if successful
  rescue => e
    failed_retryable = false
    self.file_state = "errored"
    self.workflow_state = "errored"
    case e
    when CanvasHttp::TooManyRedirectsError
      failed_retryable = true
      self.upload_error_message = t :upload_error_too_many_redirects, "Too many redirects for %{url}", url: url
    when CanvasHttp::InvalidResponseCodeError
      failed_retryable = true
      self.upload_error_message = t :upload_error_invalid_response_code, "Invalid response code, expected 200 got %{code} for %{url}", code: e.code, url: url
      Canvas::Errors.capture(e, clone_url_error_info(e, url))
    when CanvasHttp::RelativeUriError
      self.upload_error_message = t :upload_error_relative_uri, "No host provided for the URL: %{url}", url: url
    when URI::Error, ArgumentError
      # assigning all ArgumentError to InvalidUri may be incorrect
      self.upload_error_message = t :upload_error_invalid_url, "Could not parse the URL: %{url}", url: url
    when Timeout::Error
      failed_retryable = true
      self.upload_error_message = t :upload_error_timeout, "The request timed out: %{url}", url: url
    when OverQuotaError
      self.upload_error_message = t :upload_error_over_quota, "file size exceeds quota limits: %{bytes} bytes", bytes: size
    else
      failed_retryable = true
      self.upload_error_message = t :upload_error_unexpected, "An unknown error occurred downloading from %{url}", url: url
      Canvas::Errors.capture(e, clone_url_error_info(e, url))
    end

    if opts[:progress]
      opts[:progress].message = upload_error_message
      opts[:progress].fail!
    end

    save!
    failed_retryable
  end

  def crocodoc_available?
    crocodoc_document.try(:available?)
  end

  def canvadoc_available?
    canvadoc.try(:available?)
  end

  def canvadoc_url(user, opts = {})
    return unless canvadocable?

    "/api/v1/canvadoc_session?#{preview_params(user, "canvadoc", opts)}"
  end

  def crocodoc_url(user, opts = {})
    return unless crocodoc_available?

    "/api/v1/crocodoc_session?#{preview_params(user, "crocodoc", opts.merge(enable_annotations: true))}"
  end

  def previewable_media?
    self.content_type && (self.content_type.match(/\A(video|audio)/) || self.content_type == "application/x-flash-video")
  end

  def preview_params(user, type, opts = {})
    h = opts.merge({
                     user_id: user.try(:global_id),
                     attachment_id: id,
                     type: type
                   })
    blob = h.to_json
    hmac = Canvas::Security.hmac_sha1(blob)
    "blob=#{URI.encode blob}&hmac=#{URI.encode hmac}"
  end
  private :preview_params

  def can_unpublish?
    false
  end

  def self.copy_attachments_to_submissions_folder(assignment_context, attachments)
    attachments.map do |attachment|
      if attachment.folder&.for_submissions? &&
         !attachment.associated_with_submission?
        # if it's already in a submissions folder and has not been submitted previously, we can leave it there
        attachment
      elsif attachment.context.respond_to?(:submissions_folder)
        # if it's not in a submissions folder, or has previously been submitted, we need to make a copy
        attachment.copy_to_folder!(attachment.context.submissions_folder(assignment_context))
      else # rubocop:disable Lint/DuplicateBranch
        attachment # in a weird context; leave it alone
      end
    end
  end

  def copy_to_student_annotation_documents_folder(course)
    return self if folder == course.student_annotation_documents_folder

    copy_to_folder!(course.student_annotation_documents_folder)
  end

  def set_publish_state_for_usage_rights
    self.locked = if context &&
                     (!folder || !folder.for_submissions?) &&
                     context.respond_to?(:usage_rights_required?) && context.usage_rights_required?
                    usage_rights.nil?
                  else
                    false
                  end
  end

  # Download a URL using a GET request and return a new un-saved Attachment
  # with the data at that URL. Tries to detect the correct content_type as
  # well.
  #
  # This handles large files well.
  #
  # Pass an existing attachment in opts[:attachment] to use that, rather than
  # creating a new attachment.
  def self.clone_url_as_attachment(url, opts = {})
    _, uri = CanvasHttp.validate_url(url, check_host: true)

    CanvasHttp.get(url) do |http_response|
      if http_response.code.to_i == 200
        tmpfile = CanvasHttp.tempfile_for_uri(uri)
        # net/http doesn't make this very obvious, but read_body can take any
        # object that responds to << as the destination of the body, and it'll
        # stream in chunks rather than reading the whole body into memory (as
        # long as you use the block form of http.request, which
        # CanvasHttp.get does)
        http_response.read_body(tmpfile)
        tmpfile.rewind
        attachment = opts[:attachment] || Attachment.new(filename: File.basename(uri.path))
        attachment.filename ||= File.basename(uri.path)
        Attachments::Storage.store_for_attachment(attachment, tmpfile)
        if attachment.content_type.blank? || attachment.content_type == "unknown/unknown"
          # uploaded_data= clobbers the content_type set in preflight; if it was given, prefer it to the HTTP response
          attachment.content_type = if attachment.content_type_was.present? && attachment.content_type_was != "unknown/unknown"
                                      attachment.content_type_was
                                    else
                                      http_response.content_type
                                    end
        end
        return attachment
      else
        # Grab the first part of the body for error reporting
        # Just read the first chunk of the body in case it's huge
        body_head = nil

        begin
          http_response.read_body do |chunk|
            body_head = "#{chunk}..." if chunk.present?
            break
          end
        rescue
          # If an error occured reading the body, don't worry
          # about attempting to report it
          body_head = nil
        end

        raise CanvasHttp::InvalidResponseCodeError.new(http_response.code.to_i, body_head)
      end
    end
  end

  def self.migrate_attachments(from_context, to_context, scope = nil)
    from_attachments = scope
    from_attachments ||= from_context.shard.activate do
      Attachment.where(context_type: from_context.class.name, context_id: from_context).not_deleted.to_a
    end

    to_context.shard.activate do
      to_attachments = Attachment.where(context_type: to_context.class.name, context_id: to_context).not_deleted.to_a

      from_attachments.each do |attachment|
        match = to_attachments.detect { |a| attachment.matches_full_display_path?(a.full_display_path) }
        next if match && match.md5 == attachment.md5

        if from_context.shard == to_context.shard
          og_attachment = attachment
          og_attachment.context = to_context
          og_attachment.folder = Folder.assert_path(attachment.folder_path, to_context)
          og_attachment.user_id = to_context.id if to_context.is_a? User
          og_attachment.save_without_broadcasting!
          if match
            og_attachment.folder.reload
            og_attachment.handle_duplicates(:rename)
          end
        else
          if to_context.is_a? User
            attachment.user_id = to_context.id
            attachment.save_without_broadcasting!
          end
          new_attachment = Attachment.new
          new_attachment.assign_attributes(attachment.attributes.except(*EXCLUDED_COPY_ATTRIBUTES))

          new_attachment.user_id = to_context.id if to_context.is_a? User
          new_attachment.context = to_context
          new_attachment.folder = Folder.assert_path(attachment.folder_path, to_context)
          new_attachment.namespace = new_attachment.infer_namespace
          if (existing_attachment = new_attachment.find_existing_attachment_for_md5)
            new_attachment.root_attachment = existing_attachment
          else
            new_attachment.write_attribute(:filename, attachment.filename)
            Attachments::Storage.store_for_attachment(new_attachment, attachment.open)
          end

          new_attachment.content_type = attachment.content_type

          new_attachment.save_without_broadcasting!
          if match
            new_attachment.folder.reload
            new_attachment.handle_duplicates(:rename)
          end
        end
      end
    end
  end

  def calculate_words
    word_count_regex = /\S+/
    @word_count ||= if mime_class == "pdf"
                      reader = PDF::Reader.new(self.open)
                      reader.pages.sum do |page|
                        page.text.scan(word_count_regex).count
                      end
                    elsif [
                      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                      "application/x-docx"
                    ].include?(mimetype)
                      doc = Docx::Document.open(self.open)
                      doc.paragraphs.sum do |paragraph|
                        paragraph.text.scan(word_count_regex).count
                      end
                    elsif [
                      "application/rtf",
                      "text/rtf"
                    ].include?(mimetype)
                      parser = RubyRTF::Parser.new(unknown_control_warning_enabled: false)
                      parser.parse(self.open.read).sections.sum do |section|
                        section[:text].scan(word_count_regex).count
                      end
                    elsif mime_class == "text"
                      open.read.scan(word_count_regex).count
                    else
                      0
                    end
  rescue => e
    # If there is an error processing the file just log the error and return 0
    Canvas::Errors.capture_exception(:word_count, e, :info)
    0
  end

  def word_count_supported?
    ["application/vnd.openxmlformats-officedocument.wordprocessingml.document",
     "application/x-docx", "application/rtf",
     "text/rtf"].include?(mimetype) || ["pdf", "text"].include?(mime_class)
  end
end
