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
import '../tinymce/el'

const locale = {
  "add_8523c19b": { "message": "Πρόσθεση" },
  "all_4321c3a1": { "message": "Όλα" },
  "announcement_list_da155734": { "message": "Λίστα Ανακοινώσεων" },
  "announcements_a4b8ed4a": { "message": "Ανακοινώσεις" },
  "apply_781a2546": { "message": "Εφαρμογή" },
  "apps_54d24a47": { "message": "Εφαρμογές" },
  "arrows_464a3e54": { "message": "Βέλη" },
  "aspect_ratio_will_be_preserved_cb5fdfb8": {
    "message": "Ο λόγος του μήκους της εικόνας προς το ύψος της θα διατηρηθεί"
  },
  "assignments_1e02582c": { "message": "Εργασίες" },
  "attributes_963ba262": { "message": "Πεδία" },
  "basic_554cdc0a": { "message": "Βασική" },
  "blue_daf8fea9": { "message": "Μπλε" },
  "c_2001_acme_inc_283f7f80": { "message": "(c) 2001 Acme Inc." },
  "cancel_caeb1e68": { "message": "Ακύρωση" },
  "choose_usage_rights_33683854": {
    "message": "Επιλέξτε δικαιώματα χρήσης..."
  },
  "clear_2084585f": { "message": "Καθαρισμός" },
  "click_to_embed_imagename_c41ea8df": {
    "message": "Κάντε κλικ για να ενσωματώσετε την εικόνα { imageName }"
  },
  "click_to_insert_a_link_into_the_editor_c19613aa": {
    "message": "Κάντε κλικ για να εισάγετε σύνδεσμο μέσα στον επεξεργαστή"
  },
  "close_d634289d": { "message": "Κλείσιμο" },
  "collaborations_5c56c15f": { "message": "Συνεργασίες" },
  "content_1440204b": { "message": "Περιεχόμενο" },
  "content_type_2cf90d95": { "message": "Τύπος Περιεχομένου" },
  "copyright_holder_66ee111": { "message": "Κάτοχος Πνευματικών Δικαιωμάτων:" },
  "count_plural_one_item_loaded_other_items_loaded_857023b7": {
    "message": "{ count, plural,\n    one {}\n  other {}\n}"
  },
  "course_files_62deb8f8": { "message": "Αρχεία Μαθήματος" },
  "course_files_a31f97fc": { "message": "Αρχεία μαθήματος" },
  "course_navigation_dd035109": { "message": "Πλοήγηση στο μάθημα" },
  "creative_commons_license_725584ae": { "message": "Άδεια Creative Commons:" },
  "cyan_c1d5f68a": { "message": "Κυανό" },
  "decrease_indent_de6343ab": { "message": "Μείωση Εσοχής Κειμένου" },
  "deep_purple_bb3e2907": { "message": "Βαθύ μοβ" },
  "delimiters_4db4840d": { "message": "Οριοθέτες" },
  "details_98a31b68": { "message": "Λεπτομέρειες" },
  "dimensions_45ddb7b7": { "message": "Διαστάσεις" },
  "discussions_a5f96392": { "message": "Συζητήσεις" },
  "discussions_index_6c36ced": { "message": "Ευρετήριο Συζητήσεων" },
  "done_54e3d4b6": { "message": "Ολοκληρώθηκε" },
  "due_multiple_dates_cc0ee3f5": {
    "message": "<mrk mid=\"4290\" mtype=\"seg\">Καταληκτική Ημερ/νία:</mrk> <mrk mid=\"4291\" mtype=\"seg\">Πολλαπλές Ημερομηνίες</mrk>"
  },
  "edit_c5fbea07": { "message": "Διαμόρφωση" },
  "embed_image_1080badc": { "message": "Ενσωμάτωση εικόνας" },
  "external_tools_6e77821": { "message": "Εξωτερικά Εργαλεία" },
  "files_c300e900": { "message": "Αρχεία" },
  "files_index_af7c662b": { "message": "Ευρετήριο Αρχείων" },
  "format_4247a9c5": { "message": "Τύπος" },
  "generating_preview_45b53be0": { "message": "Δημιουργία προεπισκόπησης..." },
  "grades_a61eba0a": { "message": "Βαθμοί" },
  "greek_65c5b3f7": { "message": "Ελληνικά" },
  "green_15af4778": { "message": "Πράσινο" },
  "group_files_82e5dcdb": { "message": "Αρχεία ομάδας" },
  "group_navigation_99f191a": { "message": "Πλοήγηση στην Ομάδα" },
  "home_351838cd": { "message": "Αρχική Σελίδα" },
  "html_editor_fb2ab713": { "message": "Επεξεργαστής HTML" },
  "i_have_obtained_permission_to_use_this_file_6386f087": {
    "message": "Πήρα άδεια για να χρησιμοποιήσω αυτό το αρχείο."
  },
  "i_hold_the_copyright_71ee91b1": {
    "message": "Έχω τα πνευματικά δικαιώματα"
  },
  "image_8ad06": { "message": "Εικόνα" },
  "images_7ce26570": { "message": "Εικόνες" },
  "increase_indent_6d550a4a": { "message": "Αύξηση Εσοχής Κειμένου" },
  "indigo_2035fc55": { "message": "Λουλακί" },
  "insert_593145ef": { "message": "Εισαγωγή" },
  "insert_equella_links_49a8dacd": {
    "message": "Εισαγωγή Συνδέσμων τύπου Equella"
  },
  "insert_link_6dc23cae": { "message": "Εισαγωγή Συνδέσμου" },
  "insert_math_equation_57c6e767": {
    "message": "Εισαγωγή Μαθηματικής Εξίσωσης"
  },
  "invalid_file_type_881cc9b2": { "message": "Μη έγκυρος τύπος αρχείου" },
  "invalid_url_cbde79f": { "message": "Μη έγκυρο URL" },
  "keyboard_shortcuts_ed1844bd": { "message": "Συντομεύσεις πληκτρολογίου" },
  "light_blue_5374f600": { "message": "Μπλε Ανοιχτό" },
  "link_7262adec": { "message": "Σύνδεσμος" },
  "links_14b70841": { "message": "Σύνδεσμοι" },
  "load_more_results_460f49a9": {
    "message": "Φόρτωση περισσότερων αποτελεσμάτων"
  },
  "loading_25990131": { "message": "Φόρτωση..." },
  "loading_bde52856": { "message": "Φόρτωση" },
  "loading_failed_b3524381": { "message": "Η Φόρτωση Απέτυχε" },
  "locked_762f138b": { "message": "Κλειδωμένο" },
  "media_af190855": { "message": "Δεδομένα" },
  "misc_3b692ea7": { "message": "Διάφορα" },
  "modules_c4325335": { "message": "Ενότητες" },
  "my_files_2f621040": { "message": "Τα αρχεία μου" },
  "name_1aed4a1b": { "message": "Όνομα" },
  "no_e16d9132": { "message": "μη δημοσιευμένο" },
  "no_preview_is_available_for_this_file_f940114a": {
    "message": "Δεν υπάρχει διαθέσιμη προεπισκόπηση για αυτό το αρχείο."
  },
  "no_results_940393cf": { "message": "Δεν υπάρχουν Αποτελέσματα" },
  "none_3b5e34d2": { "message": "Κανένα" },
  "operators_a2ef9a93": { "message": "Χειριστές" },
  "options_3ab0ea65": { "message": "Επιλογές" },
  "orange_81386a62": { "message": "Πορτοκαλί" },
  "pages_e5414c2c": { "message": "Σελίδες" },
  "people_b4ebb13c": { "message": "Κοινό" },
  "percentage_34ab7c2c": { "message": "Εκατοστιαία αναλογία" },
  "pink_68ad45cb": { "message": "Ροζ" },
  "preview_53003fd2": { "message": "Προεπισκόπηση" },
  "published_c944a23d": { "message": "δημοσιευμένο/α" },
  "purple_7678a9fc": { "message": "Μοβ" },
  "quizzes_7e598f57": { "message": "Κουίζ" },
  "record_7c9448b": { "message": "Ηχογράφηση" },
  "red_8258edf3": { "message": "Κόκκινο" },
  "relationships_6602af70": { "message": "Σχέσεις" },
  "rich_content_editor_2708ef21": {
    "message": "Επεξεργαστής Πλούσιου Περιεχομένου-rich content"
  },
  "save_11a80ec3": { "message": "Αποθήκευση" },
  "search_280d00bd": { "message": "Αναζήτηση" },
  "size_b30e1077": { "message": "Μέγεθος" },
  "star_8d156e09": { "message": " " },
  "submit_a3cc6859": { "message": "Υποβολή" },
  "syllabus_f191f65b": { "message": "Αναλυτικό Πρόγραμμα" },
  "teal_f729a294": { "message": "Γαλαζοπράσινο" },
  "the_material_is_in_the_public_domain_279c39a3": {
    "message": "Το υλικό βρίσκεται στο δημόσιο domain"
  },
  "the_material_is_licensed_under_creative_commons_3242cb5e": {
    "message": "Το υλικό φέρει άδεια Creative Commons"
  },
  "title_ee03d132": { "message": "Τίτλος" },
  "unpublished_dfd8801": { "message": "μη δημοσιευμένο" },
  "upload_file_fd2361b8": { "message": "Φόρτωση Αρχείου" },
  "upload_media_ce31135a": { "message": "Μεταφόρτωση Αρχείου Πολυμέσων" },
  "uploading_19e8a4e7": { "message": "Γίνεται φόρτωση..." },
  "url_22a5f3b8": { "message": "URL" },
  "usage_right_ff96f3e2": { "message": "Δικαίωμα Χρήσης:" },
  "view_ba339f93": { "message": "Προβολή" },
  "white_87fa64fd": { "message": "Λευκό" },
  "wiki_home_9cd54d0": { "message": "Αρχική Σελίδα Wiki" },
  "yes_dde87d5": { "message": "Ναι" }
}


formatMessage.addLocale({el: locale})
