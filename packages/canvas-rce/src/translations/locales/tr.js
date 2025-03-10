/*
 * Copyright (C) 2021 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import formatMessage from '../../format-message'
import '../tinymce/tr_TR'

const locale = {
  "accessibility_checker_b3af1f6c": { "message": "Erişilebilirlik Kontrolü" },
  "add_8523c19b": { "message": "Ekle" },
  "add_another_f4e50d57": { "message": "Başka bir tane ekle" },
  "add_cc_subtitles_55f0394e": { "message": "Alt yazı ekle" },
  "align_11050992": { "message": "Hizala" },
  "align_center_ca078feb": { "message": "Ortala" },
  "align_left_e9f1f93b": { "message": "Sola dayalı" },
  "align_right_9bad3ac1": { "message": "Sağa dayalı" },
  "all_4321c3a1": { "message": "Tümü" },
  "alphabetical_55b5b4e0": { "message": "Alfabetik" },
  "alt_text_611fb322": { "message": "Etiket Metni" },
  "an_error_occured_reading_the_file_ff48558b": {
    "message": "Dosya okunurken hata oluştu"
  },
  "an_error_occurred_making_a_network_request_d1bda348": {
    "message": "Ağ isteğinde bulunurken bir hata oluştu"
  },
  "an_error_occurred_uploading_your_media_71f1444d": {
    "message": "Medya dosyası yüklenirken hata oluştu."
  },
  "announcement_list_da155734": { "message": "Duyuru Listesi" },
  "announcements_a4b8ed4a": { "message": "Duyurular" },
  "apply_781a2546": { "message": "Uygula" },
  "apps_54d24a47": { "message": "Uygulamalar" },
  "arrows_464a3e54": { "message": "Oklar" },
  "aspect_ratio_will_be_preserved_cb5fdfb8": {
    "message": "Genişleme oranı korumalıdır"
  },
  "assignments_1e02582c": { "message": "Ödevler" },
  "attributes_963ba262": { "message": "Özellikler" },
  "audio_player_for_title_20cc70d": { "message": "{ title } ses oynatıcı" },
  "available_folders_694d0436": { "message": "Mevcut klasörler" },
  "basic_554cdc0a": { "message": "Temel" },
  "blue_daf8fea9": { "message": "Mavi" },
  "c_2001_acme_inc_283f7f80": { "message": "(c) 2001 Acme Inc." },
  "cancel_caeb1e68": { "message": "İptal" },
  "choose_caption_file_9c45bc4e": { "message": "Alt yazı dosyasını seçin" },
  "choose_usage_rights_33683854": { "message": "Kullanıcı haklarını seçin..." },
  "circle_unordered_list_9e3a0763": {
    "message": "sıralanmamış listeyi yuvarlak içine al"
  },
  "clear_2084585f": { "message": "Temizle" },
  "clear_selected_file_82388e50": { "message": "Seçili dosyayı temizle" },
  "click_to_embed_imagename_c41ea8df": {
    "message": "{ imageName } görselini eklemek için tıklayınız"
  },
  "click_to_insert_a_link_into_the_editor_c19613aa": {
    "message": "Düzenleyiciye bağlantı eklemek için tıklayın."
  },
  "close_a_menu_or_dialog_also_returns_you_to_the_edi_739079e6": {
    "message": "Bir menü ya da diyalog kapatır. Ayrıca sizi düzenleme alanına götürür"
  },
  "close_d634289d": { "message": "Kapat" },
  "collaborations_5c56c15f": { "message": "İşbirliğine Yönelik Çalışmalar" },
  "collapse_to_hide_types_1ab46d2e": {
    "message": "{ types } gizlemek için daraltın"
  },
  "computer_1d7dfa6f": { "message": "Bilgisayar" },
  "content_1440204b": { "message": "İçerik" },
  "content_subtype_5ce35e88": { "message": "İçerik Alt Türü" },
  "content_type_2cf90d95": { "message": "İçerik Tipi" },
  "copyright_holder_66ee111": { "message": "Telif Sahibi:" },
  "count_plural_one_item_loaded_other_items_loaded_857023b7": {
    "message": "{ count, plural,\n    one {}\n  other {}\n}"
  },
  "course_documents_104d76e0": { "message": "Ders Belgeleri" },
  "course_files_62deb8f8": { "message": "Ders Dosyaları" },
  "course_files_a31f97fc": { "message": "Ders dosyaları" },
  "course_images_f8511d04": { "message": "Ders Görselleri" },
  "course_links_b56959b9": { "message": "Ders Bağlantıları" },
  "course_media_ec759ad": { "message": "Ders Medyası" },
  "course_navigation_dd035109": { "message": "Ders Gezinme Menüsü" },
  "creative_commons_license_725584ae": {
    "message": "Creative Commons Lisansı:"
  },
  "custom_6979cd81": { "message": "Özelleştir" },
  "cyan_c1d5f68a": { "message": "Cam göbeği" },
  "date_added_ed5ad465": { "message": "Eklendiği Tarih" },
  "decorative_image_3c28aa7d": { "message": "Dekoratif Görsel" },
  "decrease_indent_de6343ab": { "message": "İçerden başlatma sınırını azalt" },
  "deep_purple_bb3e2907": { "message": "Koyu Mor" },
  "delimiters_4db4840d": { "message": "Ayıraçlar" },
  "details_98a31b68": { "message": "Ayrıntılar" },
  "dimensions_45ddb7b7": { "message": "Tanımlamalar" },
  "discussions_a5f96392": { "message": "Tartışmalar" },
  "discussions_index_6c36ced": { "message": "Tartışma Başlıkları" },
  "display_options_315aba85": { "message": "Gösterim Seçenekleri" },
  "documents_81393201": { "message": "Belgeler" },
  "done_54e3d4b6": { "message": "Tamam" },
  "drag_a_file_here_1bf656d5": { "message": "Buraya bir Dosya Sürükleyin" },
  "drag_and_drop_or_click_to_browse_your_computer_60772d6d": {
    "message": "Sürükleyip bırakın ya da bilgisayarınıza gözatın"
  },
  "due_multiple_dates_cc0ee3f5": { "message": "Teslim Tarihi: Birden Çok Gün" },
  "edit_c5fbea07": { "message": "Düzenle" },
  "edit_link_7f53bebb": { "message": "Bağlantıyı Düzenle" },
  "embed_828fac4a": { "message": "Göm" },
  "embed_image_1080badc": { "message": "Görsel Ekle" },
  "embed_options_tray_901cfd19": { "message": "Gömme Seçenekleri Yan Menüsü" },
  "embed_preview_2d741e1f": { "message": "Gömme Önizleme" },
  "external_links_3d9f074e": { "message": "Harici Bağlantılar" },
  "external_tools_6e77821": { "message": "Harici Araçlar" },
  "extra_large_b6cdf1ff": { "message": "Ekstra Büyük" },
  "file_url_c12b64be": { "message": "Dosya URL" },
  "files_c300e900": { "message": "Dosyalar" },
  "files_index_af7c662b": { "message": "Dosya Başlıkları" },
  "format_4247a9c5": { "message": "Format" },
  "generating_preview_45b53be0": { "message": "Oluşturma önizlemesi..." },
  "grades_a61eba0a": { "message": "Notlar" },
  "greek_65c5b3f7": { "message": "Yunan" },
  "green_15af4778": { "message": "Yeşil" },
  "group_files_82e5dcdb": { "message": "Grup dosyaları" },
  "group_navigation_99f191a": { "message": "Grup Gezinme Menüsü" },
  "heading_2_5b84eed2": { "message": "Başlık 2" },
  "heading_3_2c83de44": { "message": "Başlık 3" },
  "heading_4_b2e74be7": { "message": "Başlık 4" },
  "height_69b03e15": { "message": "Yükseklik" },
  "home_351838cd": { "message": "Ana Sayfa" },
  "html_editor_fb2ab713": { "message": "HTML Düzenleyici" },
  "i_have_obtained_permission_to_use_this_file_6386f087": {
    "message": "Bu dosyayı kullanmak için iznim var."
  },
  "i_hold_the_copyright_71ee91b1": { "message": "Telif hakkı bendedir" },
  "image_8ad06": { "message": "Görsel" },
  "image_options_5412d02c": { "message": "Görsel Seçenekleri" },
  "image_options_tray_90a46006": { "message": "Görsel Seçenekleri Yan Menüsü" },
  "images_7ce26570": { "message": "Görseller" },
  "increase_indent_6d550a4a": { "message": "İçerden başlat" },
  "indigo_2035fc55": { "message": "Indigo" },
  "insert_593145ef": { "message": "Ekle" },
  "insert_equella_links_49a8dacd": { "message": "Equella Bağlantısı Ekle" },
  "insert_link_6dc23cae": { "message": "Bağlantı Ekle" },
  "insert_math_equation_57c6e767": { "message": "Matematik Denklemi Ekle" },
  "invalid_file_c11ba11": { "message": "Geçersiz Dosya" },
  "invalid_file_type_881cc9b2": { "message": "Geçersiz dosya türü" },
  "invalid_url_cbde79f": { "message": "Geçersiz bağlantı" },
  "keyboard_shortcuts_ed1844bd": { "message": "Klavye Kısayolları" },
  "large_9c5e80e7": { "message": "Büyük" },
  "light_blue_5374f600": { "message": "Açık Mavi" },
  "link_7262adec": { "message": "Bağlantı" },
  "link_options_a16b758b": { "message": "Bağlantı Seçenekleri" },
  "links_14b70841": { "message": "Bağlantılar" },
  "load_more_35d33c7": { "message": "Daha Fazla Yükle" },
  "load_more_results_460f49a9": { "message": "Daha fazla sonuç yükle" },
  "loading_25990131": { "message": "Yükleniyor..." },
  "loading_bde52856": { "message": "Yükleniyor" },
  "loading_failed_b3524381": { "message": "Yükleme Başarısız..." },
  "locked_762f138b": { "message": "Kilitli" },
  "media_af190855": { "message": "Medya" },
  "misc_3b692ea7": { "message": "Çeşitli" },
  "modules_c4325335": { "message": "Modüller" },
  "my_files_2f621040": { "message": "Dosyalarım" },
  "name_1aed4a1b": { "message": "İsim" },
  "next_page_d2a39853": { "message": "Sonraki Sayfa" },
  "no_e16d9132": { "message": "Hayır" },
  "no_preview_is_available_for_this_file_f940114a": {
    "message": "Bu dosya için ön izleme bulunmamaktadır."
  },
  "no_results_940393cf": { "message": "Sonuç yok." },
  "none_3b5e34d2": { "message": "Yok" },
  "operators_a2ef9a93": { "message": "Operatörler" },
  "options_3ab0ea65": { "message": "Seçenekler" },
  "orange_81386a62": { "message": "Turuncu" },
  "pages_e5414c2c": { "message": "Sayfalar" },
  "people_b4ebb13c": { "message": "Katılımcılar" },
  "percentage_34ab7c2c": { "message": "Yüzde" },
  "pink_68ad45cb": { "message": "Pembe" },
  "preview_53003fd2": { "message": "Önizleme" },
  "previous_page_928fc112": { "message": "Önceki Sayfa" },
  "published_c944a23d": { "message": "yayınlandı" },
  "purple_7678a9fc": { "message": "Mor" },
  "quizzes_7e598f57": { "message": "Kısa sınavlar" },
  "record_7c9448b": { "message": "Kayıt" },
  "red_8258edf3": { "message": "Kırmızı" },
  "relationships_6602af70": { "message": "İlişkiler" },
  "rich_content_editor_2708ef21": { "message": "Zengin İçerik Editörü" },
  "save_11a80ec3": { "message": "Kaydet" },
  "search_280d00bd": { "message": "Ara" },
  "size_b30e1077": { "message": "Boyut" },
  "something_went_wrong_89195131": { "message": "Bazı sorunlar oluştu." },
  "sort_by_e75f9e3e": { "message": "Sırala" },
  "star_8d156e09": { "message": "Yıldız Ver" },
  "submit_a3cc6859": { "message": "Gönder" },
  "syllabus_f191f65b": { "message": "Ders Programı" },
  "the_material_is_in_the_public_domain_279c39a3": {
    "message": "Bu malzeme genel kullanıma açık"
  },
  "the_material_is_licensed_under_creative_commons_3242cb5e": {
    "message": "Bu malzeme Creative Commons a göre lisanslı"
  },
  "title_ee03d132": { "message": "Başlık" },
  "to_be_posted_when_d24bf7dc": { "message": "Gönderileceği zaman: { when }" },
  "totalresults_results_found_numdisplayed_results_cu_a0a44975": {
    "message": "{ totalResults } rsonuç bulundu, { numDisplayed } sonuç halihazırda gösteriliyor"
  },
  "tray_839df38a": { "message": "Yan menü" },
  "type_control_f9_to_access_image_options_text_a47e319f": {
    "message": "görsel seçeneklerine ulaşmak için Kontrol F9 tuşuna basın. { text }"
  },
  "type_control_f9_to_access_link_options_text_4ead9682": {
    "message": "Erişim bağlantısı seçeneklerine ulaşmak için Kontrol F9 tuşuna basın. { text }"
  },
  "type_control_f9_to_access_table_options_text_92141329": {
    "message": "Erişim tablosu seçeneklerine ulaşmak için Kontrol F9 tuşuna basın. { text }"
  },
  "unpublished_dfd8801": { "message": "yayınlanmadı" },
  "upload_document_253f0478": { "message": "Belge Yükle" },
  "upload_file_fd2361b8": { "message": "Dosya Yükle" },
  "upload_image_6120b609": { "message": "Görsel Yükle" },
  "upload_media_ce31135a": { "message": "Medya Dosyası Yükle" },
  "uploading_19e8a4e7": { "message": "Yükleniyor" },
  "uppercase_alphabetic_ordered_list_3f5aa6b2": {
    "message": "Büyük harf alfabetik sıralı liste"
  },
  "url_22a5f3b8": { "message": "URL" },
  "usage_right_ff96f3e2": { "message": "Kullanım Şartları:" },
  "used_by_screen_readers_to_describe_the_content_of__b1e76d9e": {
    "message": "Ekran okuyucuları tarafından bir görselin içeriğini açıklamak için kullanılır"
  },
  "used_by_screen_readers_to_describe_the_video_37ebad25": {
    "message": "Ekran okuyucuları tarafından videoyu açıklamak için kullanılır"
  },
  "user_documents_c206e61f": { "message": "Kullanıcı Belgeleri" },
  "user_images_b6490852": { "message": "Kullanıcı Görselleri" },
  "user_media_14fbf656": { "message": "Kullanıcı Medya Dosyası" },
  "video_options_24ef6e5d": { "message": "Video Seçenekleri" },
  "video_options_tray_3b9809a5": { "message": "Video Seçenekleri Yan Menüsü" },
  "view_ba339f93": { "message": "Göster" },
  "view_keyboard_shortcuts_34d1be0b": {
    "message": "Klavye Kısayollarını Göster"
  },
  "width_492fec76": { "message": "Genişlik" },
  "width_and_height_must_be_numbers_110ab2e3": {
    "message": "Genişlik ve yükseklik rakam olmalı"
  },
  "width_x_height_px_ff3ccb93": { "message": "{ width } x { height }px" },
  "wiki_home_9cd54d0": { "message": "Wiki Ana Sayfası" },
  "yes_dde87d5": { "message": "Evet" }
}


formatMessage.addLocale({tr: locale})
