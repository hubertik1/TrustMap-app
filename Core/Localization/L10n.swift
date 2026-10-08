import Foundation

/// App-owned copy. User content and API identifiers must never pass through this API.
enum L10n {
    static let supportedLanguages = ["en", "pl", "de", "es", "fr", "it", "pt", "uk"]

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }

    private static func text(_ key: String) -> String {
        resourceBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    private static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }

    static var preparingTrustmap: String { text("ui.preparing_trustmap") }

    static var map: String { text("ui.map") }

    static var places: String { text("ui.places") }

    static var add: String { text("ui.add") }

    static var feed: String { text("ui.feed") }

    static var profile: String { text("ui.profile") }

    static var addReview: String { text("ui.add_review") }

    static var activity: String { text("ui.activity") }

    static var refresh: String { text("ui.refresh") }

    static var settings: String { text("ui.settings") }

    static var notifications: String { text("ui.notifications") }

    static var navigate: String { text("ui.navigate") }

    static var settingsMenu: String { text("ui.settings_menu") }

    static var theServerReturnedAnUnexpectedResponse: String { text("ui.the_server_returned_an_unexpected_response") }

    static var theServerResponseWasInvalid: String { text("ui.the_server_response_was_invalid") }

    static var theBackendUrlIsInvalid: String { text("ui.the_backend_url_is_invalid") }

    static var theServerReturnedAnEmptyResponse: String { text("ui.the_server_returned_an_empty_response") }

    static var theAppCouldNotDecodeTheServerResponse: String { text("ui.the_app_could_not_decode_the_server_response") }

    static var theAppCouldNotSaveTheSessionSecurely: String { text("ui.the_app_could_not_save_the_session_securely") }

    static var theAppCouldNotUpdateTheSavedSession: String { text("ui.the_app_could_not_update_the_saved_session") }

    static var yourSessionCouldNotBeRestored: String { text("ui.your_session_could_not_be_restored") }

    static var noSignedInUserIsAvailable: String { text("ui.no_signed_in_user_is_available") }

    static var selectAPlaceBeforeContinuing: String { text("ui.select_a_place_before_continuing") }

    static var couldNotConnectToTheServer: String { text("ui.could_not_connect_to_the_server") }

    static var standard: String { text("ui.standard") }

    static var satellite: String { text("ui.satellite") }

    static var system: String { text("ui.system") }

    static var light: String { text("ui.light") }

    static var dark: String { text("ui.dark") }

    static var yourAccountHasBeenDeleted: String { text("ui.your_account_has_been_deleted") }

    static var remainingCleanupWillFinishAutomaticallyInTheBackground: String { text("ui.remaining_cleanup_will_finish_automatically_in_the_background") }

    static var yourAppleSignInIsNoLongerValidSignInAgainToContinue: String { text("ui.your_apple_sign_in_is_no_longer_valid_sign_in_again_to_continue") }

    static var addPlaceReview: String { text("ui.add_place_review") }

    static var addDishReview: String { text("ui.add_dish_review") }

    static var editPlaceReview: String { text("ui.edit_place_review") }

    static var recentPlaces: String { text("ui.recent_places") }

    static var rateAPlaceAndShareYourExperience: String { text("ui.rate_a_place_and_share_your_experience") }

    static var reviewADishFromARestaurantYouVisited: String { text("ui.review_a_dish_from_a_restaurant_you_visited") }

    static var couldnTLoadRecentPlaces: String { text("ui.couldn_t_load_recent_places") }

    static var placesYouVeReviewedRecentlyWillShowUpHere: String { text("ui.places_you_ve_reviewed_recently_will_show_up_here") }

    static var editReview: String { text("ui.edit_review") }

    static var dish: String { text("ui.dish") }

    static var close: String { text("ui.close") }

    static var rateAPlaceFirst: String { text("ui.rate_a_place_first") }

    static var toAddADishReviewFirstChooseARestaurantAndRateIt: String { text("ui.to_add_a_dish_review_first_choose_a_restaurant_and_rate_it") }

    static var chooseARatedRestaurant: String { text("ui.choose_a_rated_restaurant") }

    static var pickAPlaceYouVeAlreadyReviewedToAddADish: String { text("ui.pick_a_place_you_ve_already_reviewed_to_add_a_dish") }

    static var searchRatedRestaurants: String { text("ui.search_rated_restaurants") }

    static var rateAnotherPlace: String { text("ui.rate_another_place") }

    static var rateAnotherPlaceAccessibility: String { text("ui.rate_another_place_accessibility") }

    static var theAppleSignInRequestCouldNotBeValidated: String { text("ui.the_apple_sign_in_request_could_not_be_validated") }

    static var appleDidNotReturnAValidIdentityToken: String { text("ui.apple_did_not_return_a_valid_identity_token") }

    static var keepThePlacesYourPeopleTrustAllInOneMap: String { text("ui.keep_the_places_your_people_trust_all_in_one_map") }

    static var saveFavoriteSpotsCompareNotesAndRevisitTrustedPicksFromYourFriends: String { text("ui.save_favorite_spots_compare_notes_and_revisit_trusted_picks_from_your_friends") }

    static var privateRecommendationsFromTrustedFriends: String { text("ui.private_recommendations_from_trusted_friends") }

    static var previewOfTheRealTrustmapProductShowingTheWelcomeMapScreen: String { text("ui.preview_of_the_real_trustmap_product_showing_the_welcome_map_screen") }

    static var privacyPolicy: String { text("ui.privacy_policy") }

    static var support: String { text("ui.support") }
    static var contactSupport: String { text("ui.contact_support") }

    static var signingIn: String { text("ui.signing_in") }

    static var signingInWaitingForTheServer: String { text("ui.signing_in_waiting_for_the_server") }

    static var signInWithAppleIsUnavailableInSwiftuiPreviewsRunTrustmapInTheSimulatorOrOnADeviceToTestAut: String { text("ui.sign_in_with_apple_is_unavailable_in_swiftui_previews_run_trustmap_in_the_simulator_or_on_a_device_to_test_aut") }

    static var chooseACategoryForThisPlace: String { text("ui.choose_a_category_for_this_place") }

    static var enterADishName: String { text("ui.enter_a_dish_name") }

    static var theDishReviewCouldNotBeSavedBecauseThePhotoUploadFailedNothingWasChanged: String { text("ui.the_dish_review_could_not_be_saved_because_the_photo_upload_failed_nothing_was_changed") }

    static var unableToSaveDishReview: String { text("ui.unable_to_save_dish_review") }

    static var unableToDeleteDishReview: String { text("ui.unable_to_delete_dish_review") }

    static var editDishReview: String { text("ui.edit_dish_review") }

    static var theSelectedPhotoCouldnTBePrepared: String { text("ui.the_selected_photo_couldn_t_be_prepared") }

    static var chooseARating: String { text("ui.choose_a_rating") }

    static var chooseAnActiveCategory: String { text("ui.choose_an_active_category") }

    static var noEditableDishReviewExistsForThisPlace: String { text("ui.no_editable_dish_review_exists_for_this_place") }

    static var cancel: String { text("ui.cancel") }

    static var save: String { text("ui.save") }

    static var place: String { text("ui.place") }

    static var dishReview: String { text("ui.dish_review") }

    static var dishName: String { text("ui.dish_name") }

    static var rating: String { text("ui.rating") }

    static var shortReviewOptional: String { text("ui.short_review_optional") }

    static var price: String { text("ui.price") }

    static var category: String { text("ui.category") }

    static var noActiveCategories: String { text("ui.no_active_categories") }

    static var addTheRestaurantsCategoryBackToYourActiveCategoriesBeforeSaving: String { text("ui.add_the_restaurants_category_back_to_your_active_categories_before_saving") }

    static var photo: String { text("ui.photo") }

    static var someSelectedPhotosCouldnTBePrepared: String { text("ui.some_selected_photos_couldn_t_be_prepared") }

    static var currentPhotos: String { text("ui.current_photos") }

    static var deleteDishReview: String { text("ui.delete_dish_review") }

    static var deleteThisDishReview: String { text("ui.delete_this_dish_review") }

    static var thisActionCanTBeUndone: String { text("ui.this_action_can_t_be_undone") }

    static var dangerZone: String { text("ui.danger_zone") }

    static var replacePhoto: String { text("ui.replace_photo") }

    static var addPhoto: String { text("ui.add_photo") }

    static var willReplace: String { text("ui.will_replace") }

    static var placeReview: String { text("ui.place_review") }

    static var loadingActivity: String { text("ui.loading_activity") }

    static var noActivityYet: String { text("ui.no_activity_yet") }

    static var reviewsFromYouAndYourFriendsWillAppearHere: String { text("ui.reviews_from_you_and_your_friends_will_appear_here") }

    static var couldnTRefreshActivity: String { text("ui.couldn_t_refresh_activity") }

    static var selected: String { text("ui.selected") }

    static var notSelected: String { text("ui.not_selected") }

    static var opensPlaceDetails: String { text("ui.opens_place_details") }

    static var noMatchingActivity: String { text("ui.no_matching_activity") }

    static var tryAnotherFilter: String { text("ui.try_another_filter") }

    static var showAll: String { text("ui.show_all") }

    static func valueAtValue(_ value1: String, _ value2: String) -> String {
        format("ui.value_at_value", value1, value2)
    }

    static func dishAtValue(_ value1: String) -> String {
        format("ui.dish_at_value", value1)
    }

    static var justNow: String { text("ui.just_now") }

    static var accepted: String { text("ui.accepted") }

    static var canceled: String { text("ui.canceled") }

    static var pending: String { text("ui.pending") }

    static var rejected: String { text("ui.rejected") }

    static var loadingFriends: String { text("ui.loading_friends") }

    static var friends: String { text("ui.friends") }

    static var searchNamesOrUsernames: String { text("ui.search_names_or_usernames") }

    static var clearSearch: String { text("ui.clear_search") }

    static var couldnTRefreshFriends: String { text("ui.couldn_t_refresh_friends") }

    static var searchingUsers: String { text("ui.searching_users") }

    static var noUsers: String { text("ui.no_users") }

    static var incomingRequests: String { text("ui.incoming_requests") }

    static var youDonTHaveAnyIncomingRequestsRightNow: String { text("ui.you_don_t_have_any_incoming_requests_right_now") }

    static var accept: String { text("ui.accept") }

    static var reject: String { text("ui.reject") }

    static var outgoingRequests: String { text("ui.outgoing_requests") }

    static var youHavenTSentAnyPendingRequests: String { text("ui.you_haven_t_sent_any_pending_requests") }

    static var youDonTHaveAnyAcceptedFriendsYet: String { text("ui.you_don_t_have_any_accepted_friends_yet") }

    static var cancelRequest: String { text("ui.cancel_request") }

    static var keep: String { text("ui.keep") }

    static func addedValue(_ value1: String) -> String {
        format("ui.added_value", value1)
    }

    static var remove: String { text("ui.remove") }

    static var removeFriend: String { text("ui.remove_friend") }

    static func areYouSureYouWantToRemoveValue(_ value1: String) -> String {
        format("ui.are_you_sure_you_want_to_remove_value", value1)
    }

    static var incoming: String { text("ui.incoming") }

    static var you: String { text("ui.you") }

    static var confirm: String { text("ui.confirm") }

    static var confirmCancelRequest: String { text("ui.confirm_cancel_request") }

    static var areYouSureYouWantToCancelThisFriendRequest: String { text("ui.are_you_sure_you_want_to_cancel_this_friend_request") }

    static var noFriendsToShow: String { text("ui.no_friends_to_show") }

    static func valueDoesNotHaveVisibleFriendsYet(_ value1: String) -> String {
        format("ui.value_does_not_have_visible_friends_yet", value1)
    }

    static var friendListPrivate: String { text("ui.friend_list_private") }

    static var thisUserKeepsTheirFriendListPrivate: String { text("ui.this_user_keeps_their_friend_list_private") }

    static func friendsSinceValue(_ value1: String) -> String {
        format("ui.friends_since_value", value1)
    }

    static var anyone: String { text("ui.anyone") }

    static var me: String { text("ui.me") }

    static var recentlyUpdated: String { text("ui.recently_updated") }

    static var highestRated: String { text("ui.highest_rated") }

    static var lowestRated: String { text("ui.lowest_rated") }

    static var mostReviewed: String { text("ui.most_reviewed") }

    static var leastReviewed: String { text("ui.least_reviewed") }

    static var allVisiblePlaces: String { text("ui.all_visible_places") }

    static func ratingValueValue5(_ value1: String, _ value2: String) -> String {
        format("ui.rating_value_value_5", value1, value2)
    }

    static var reviewedPlace: String { text("ui.reviewed_place") }

    static var allVisible: String { text("ui.all_visible") }

    static var includeSelected: String { text("ui.include_selected") }

    static var excludeSelected: String { text("ui.exclude_selected") }

    static var unknownPlace: String { text("ui.unknown_place") }

    static var trustmapIsRequestingAccessToYourLocationToCenterTheMapAroundYou: String { text("ui.trustmap_is_requesting_access_to_your_location_to_center_the_map_around_you") }

    static var findingYourCurrentLocation: String { text("ui.finding_your_current_location") }

    static var locationAccessIsOffEnableItInSettingsToCenterTheMapOnYourCurrentPosition: String { text("ui.location_access_is_off_enable_it_in_settings_to_center_the_map_on_your_current_position") }

    static var locationAccessIsRestrictedOnThisDevice: String { text("ui.location_access_is_restricted_on_this_device") }

    static var selectedPlace: String { text("ui.selected_place") }

    static var pinnedLocation: String { text("ui.pinned_location") }

    static var droppedPin: String { text("ui.dropped_pin") }

    static var selectedFromMap: String { text("ui.selected_from_map") }

    static var filters: String { text("ui.filters") }

    static var addedBy: String { text("ui.added_by") }

    static var ratingRange: String { text("ui.rating_range") }

    static func minimumRatingValue(_ value1: String) -> String {
        format("ui.minimum_rating_value", value1)
    }

    static func maximumRatingValue(_ value1: String) -> String {
        format("ui.maximum_rating_value", value1)
    }

    static var resetFilters: String { text("ui.reset_filters") }

    static var mapFilters: String { text("ui.map_filters") }

    static var apply: String { text("ui.apply") }

    static var loadingYourMap: String { text("ui.loading_your_map") }

    static var centerOnMyLocation: String { text("ui.center_on_my_location") }

    static var switchToStandardMap: String { text("ui.switch_to_standard_map") }

    static var switchToSatelliteMap: String { text("ui.switch_to_satellite_map") }

    static var filtersActive: String { text("ui.filters_active") }

    static var couldnTRefreshMap: String { text("ui.couldn_t_refresh_map") }

    static var noPlacesMatchYourFilters: String { text("ui.no_places_match_your_filters") }

    static var tryChangingFiltersOrMovingTheMap: String { text("ui.try_changing_filters_or_moving_the_map") }

    static var noReviewedPlacesInThisAreaYet: String { text("ui.no_reviewed_places_in_this_area_yet") }

    static var moveTheMapOrAddAReview: String { text("ui.move_the_map_or_add_a_review") }

    static func openValue(_ value1: String) -> String {
        format("ui.open_value", value1)
    }

    static var directions: String { text("ui.directions") }

    static var opensAppleMaps: String { text("ui.opens_apple_maps") }

    static var viewPlace: String { text("ui.view_place") }

    static var searchPlaces: String { text("ui.search_places") }

    static var on: String { text("ui.on") }

    static var quiet: String { text("ui.quiet") }

    static var temporary: String { text("ui.temporary") }

    static var off: String { text("ui.off") }

    static var notRequested: String { text("ui.not_requested") }

    static func valueAddedAPlaceReview(_ value1: String) -> String {
        format("ui.value_added_a_place_review", value1)
    }

    static func valueAddedADishReview(_ value1: String) -> String {
        format("ui.value_added_a_dish_review", value1)
    }

    static func valueSentYouAFriendRequest(_ value1: String) -> String {
        format("ui.value_sent_you_a_friend_request", value1)
    }

    static var openFriendsToRespond: String { text("ui.open_friends_to_respond") }

    static var someone: String { text("ui.someone") }

    static var unread: String { text("ui.unread") }

    static var loadingNotifications: String { text("ui.loading_notifications") }

    static var noNotificationsYet: String { text("ui.no_notifications_yet") }

    static var friendActivityAndRequestsWillAppearHere: String { text("ui.friend_activity_and_requests_will_appear_here") }

    static var markAllRead: String { text("ui.mark_all_read") }

    static var couldnTOpenNotification: String { text("ui.couldn_t_open_notification") }

    static var couldnTRefreshNotifications: String { text("ui.couldn_t_refresh_notifications") }

    static var opensNotification: String { text("ui.opens_notification") }

    static var thisReviewIsNoLongerAvailable: String { text("ui.this_review_is_no_longer_available") }

    static var thisPlaceOrReviewIsNoLongerAvailable: String { text("ui.this_place_or_review_is_no_longer_available") }

    static var allCategories: String { text("ui.all_categories") }

    static var providerVenue: String { text("ui.provider_venue") }

    static var customPin: String { text("ui.custom_pin") }

    static var approvedPublic: String { text("ui.approved_public") }

    static var enterAPlaceName: String { text("ui.enter_a_place_name") }

    static var enterACategoryName: String { text("ui.enter_a_category_name") }

    static var nameCustomPlace: String { text("ui.name_custom_place") }

    static var renameCustomPlace: String { text("ui.rename_custom_place") }

    static var trustmapUser: String { text("ui.trustmap_user") }

    static var nearest: String { text("ui.nearest") }

    static func filtersValueActive(_ value1: String) -> String {
        format("ui.filters_value_active", value1)
    }

    static var loadingPlaceDetails: String { text("ui.loading_place_details") }

    static var couldnTRefreshPlaceDetails: String { text("ui.couldn_t_refresh_place_details") }

    static var noPlaceReviewsYet: String { text("ui.no_place_reviews_yet") }

    static var visiblePlaceReviewsForThisLocationWillAppearHere: String { text("ui.visible_place_reviews_for_this_location_will_appear_here") }

    static var placeReviews: String { text("ui.place_reviews") }

    static var noDishReviewsYet: String { text("ui.no_dish_reviews_yet") }

    static var dishReviewsAddedForThisPlaceWillAppearHere: String { text("ui.dish_reviews_added_for_this_place_will_appear_here") }

    static var dishReviews: String { text("ui.dish_reviews") }

    static var addDish: String { text("ui.add_dish") }

    static var customPlaceName: String { text("ui.custom_place_name") }

    static var sharedName: String { text("ui.shared_name") }

    static var onlyTheOriginalCreatorOfACustomMapPinCanChangeThisSharedName: String { text("ui.only_the_original_creator_of_a_custom_map_pin_can_change_this_shared_name") }

    static var done: String { text("ui.done") }

    static var canTAddDishReview: String { text("ui.can_t_add_dish_review") }

    static var findThePlaceYouWantToReview: String { text("ui.find_the_place_you_want_to_review") }

    static var searchingPlaces: String { text("ui.searching_places") }

    static var somethingWentWrong: String { text("ui.something_went_wrong") }

    static var tryAgain: String { text("ui.try_again") }

    static var couldnTSearchPlaces: String { text("ui.couldn_t_search_places") }

    static func dishReviewsAreAvailableOnlyForPlacesInTheValueCategory(_ value1: String) -> String {
        format("ui.dish_reviews_are_available_only_for_places_in_the_value_category", value1)
    }

    static var loadingPlaces: String { text("ui.loading_places") }

    static var noPlacesYet: String { text("ui.no_places_yet") }

    static var addYourFirstReviewToStartBuildingYourTrustedPlaces: String { text("ui.add_your_first_review_to_start_building_your_trusted_places") }

    static var couldnTRefreshPlaces: String { text("ui.couldn_t_refresh_places") }

    static var searchPlacesOrDishes: String { text("ui.search_places_or_dishes") }

    static func noResultsForValue(_ value1: String) -> String {
        format("ui.no_results_for_value", value1)
    }

    static var noMatchingPlaces: String { text("ui.no_matching_places") }

    static var tryADifferentSearchOrAdjustYourFilters: String { text("ui.try_a_different_search_or_adjust_your_filters") }

    static var tryAdjustingYourFilters: String { text("ui.try_adjusting_your_filters") }

    static var selectAPlace: String { text("ui.select_a_place") }

    static var chooseAReviewedPlaceFromTheListToSeeDetailsReviewsAndActions: String { text("ui.choose_a_reviewed_place_from_the_list_to_see_details_reviews_and_actions") }

    static var all: String { text("ui.all") }

    static var nearby: String { text("ui.nearby") }

    static var currentLocationIsUnavailable: String { text("ui.current_location_is_unavailable") }

    static var mine: String { text("ui.mine") }

    static var addedOrReviewedBy: String { text("ui.added_or_reviewed_by") }

    static var sortBy: String { text("ui.sort_by") }

    static var minimumRating: String { text("ui.minimum_rating") }

    static var any: String { text("ui.any") }

    static var dishes: String { text("ui.dishes") }

    static var reviewsArePrivate: String { text("ui.reviews_are_private") }

    static var thisUserDoesnTAllowYouToViewTheirRatedPlacesOrReviewedDishes: String { text("ui.this_user_doesn_t_allow_you_to_view_their_rated_places_or_reviewed_dishes") }

    static var yourTrustedNetwork: String { text("ui.your_trusted_network") }

    static var displayNameIsRequired: String { text("ui.display_name_is_required") }

    static var displayNameMustBe100CharactersOrFewer: String { text("ui.display_name_must_be_100_characters_or_fewer") }

    static var enterAUsername: String { text("ui.enter_a_username") }

    static var usernameMustBeAtLeast3Characters: String { text("ui.username_must_be_at_least_3_characters") }

    static var usernameMustBe32CharactersOrFewer: String { text("ui.username_must_be_32_characters_or_fewer") }

    static var bioMustBe500CharactersOrFewer: String { text("ui.bio_must_be_500_characters_or_fewer") }

    static var loadingProfile: String { text("ui.loading_profile") }

    static var profileUnavailable: String { text("ui.profile_unavailable") }

    static var weCouldnTLoadThisProfile: String { text("ui.we_couldn_t_load_this_profile") }

    static var couldnTRefreshProfile: String { text("ui.couldn_t_refresh_profile") }

    static var couldnTLoadAllReviews: String { text("ui.couldn_t_load_all_reviews") }

    static var thisProfileIsPrivate: String { text("ui.this_profile_is_private") }

    static var thisUserDoesnTAllowYouToViewTheirProfile: String { text("ui.this_user_doesn_t_allow_you_to_view_their_profile") }

    static var noReviewedDishesYet: String { text("ui.no_reviewed_dishes_yet") }

    static var dishesYouReviewWillAppearHere: String { text("ui.dishes_you_review_will_appear_here") }

    static var reviewedDishes: String { text("ui.reviewed_dishes") }

    static var searchReviewedDishes: String { text("ui.search_reviewed_dishes") }

    static var noMatchingDishes: String { text("ui.no_matching_dishes") }

    static var tryADifferentSearch: String { text("ui.try_a_different_search") }

    static var noRatedPlacesYet: String { text("ui.no_rated_places_yet") }

    static var placesYouReviewWillAppearHere: String { text("ui.places_you_review_will_appear_here") }

    static var ratedPlaces: String { text("ui.rated_places") }

    static var searchRatedPlaces: String { text("ui.search_rated_places") }

    static var noMatchingRatedPlaces: String { text("ui.no_matching_rated_places") }

    static var profilePhoto: String { text("ui.profile_photo") }

    static var editProfile: String { text("ui.edit_profile") }

    static var noBioYet: String { text("ui.no_bio_yet") }

    static var addAShortBioToHelpFriendsRecognizeYou: String { text("ui.add_a_short_bio_to_help_friends_recognize_you") }

    static var opensFriends: String { text("ui.opens_friends") }

    static var opensPlaces: String { text("ui.opens_places") }

    static var opensDishes: String { text("ui.opens_dishes") }

    static func valueFriends1PendingRequest(_ value1: String) -> String {
        format("ui.value_friends_1_pending_request", value1)
    }

    static func valueFriendsValuePendingRequests(_ value1: String, _ value2: String) -> String {
        format("ui.value_friends_value_pending_requests", value1, value2)
    }

    static var unableToUsePhoto: String { text("ui.unable_to_use_photo") }

    static var dragToRepositionPinchToZoom: String { text("ui.drag_to_reposition_pinch_to_zoom") }

    static var adjustPhoto: String { text("ui.adjust_photo") }

    static var usePhoto: String { text("ui.use_photo") }

    static var photoCropArea: String { text("ui.photo_crop_area") }

    static var opensEditReview: String { text("ui.opens_edit_review") }

    static func updatedValueValue(_ value1: String, _ value2: String) -> String {
        format("ui.updated_value_value", value1, value2)
    }

    static var noDishPhoto: String { text("ui.no_dish_photo") }

    static var friendsOfFriends: String { text("ui.friends_of_friends") }

    static var privateVisibility: String { text("ui.private") }

    static var everyone: String { text("ui.everyone") }

    static var weCouldnTLoadYourAccountData: String { text("ui.we_couldn_t_load_your_account_data") }

    static var network: String { text("ui.network") }

    static var yourActivity: String { text("ui.your_activity") }

    static var manage: String { text("ui.manage") }

    static var categories: String { text("ui.categories") }

    static func friendsValueValue(_ value1: String, _ value2: String) -> String {
        format("ui.friends_value_value", value1, value2)
    }

    static var publicProfile: String { text("ui.public_profile") }

    static var confirmDiscardChanges: String { text("ui.confirm_discard_changes") }

    static var discardChanges: String { text("ui.discard_changes") }

    static var keepEditing: String { text("ui.keep_editing") }

    static var yourProfileEditsWonTBeSaved: String { text("ui.your_profile_edits_won_t_be_saved") }

    static var unableToSaveProfile: String { text("ui.unable_to_save_profile") }

    static var displayName: String { text("ui.display_name") }

    static var username: String { text("ui.username") }

    static var onlyTheNameBeforeTheSuffixCanBeChanged: String { text("ui.only_the_name_before_the_suffix_can_be_changed") }

    static var bio: String { text("ui.bio") }

    static var changePhoto: String { text("ui.change_photo") }

    static var removePhoto: String { text("ui.remove_photo") }

    static var removesYourProfilePhoto: String { text("ui.removes_your_profile_photo") }

    static var yourPhotoAppearsNextToYourReviewsAndActivity: String { text("ui.your_photo_appears_next_to_your_reviews_and_activity") }

    static var couldnTLoadTheSelectedPhotoTryAnotherImage: String { text("ui.couldn_t_load_the_selected_photo_try_another_image") }

    static var couldnTPreparePhotoTryAnotherImage: String { text("ui.couldn_t_prepare_photo_try_another_image") }

    static var tellFriendsWhatKindOfPlacesYouLike: String { text("ui.tell_friends_what_kind_of_places_you_like") }

    static var bioCharacterCount: String { text("ui.bio_character_count") }

    static var editablePartOfYourUniqueUsername: String { text("ui.editable_part_of_your_unique_username") }

    static var readOnlyAutomaticSuffix: String { text("ui.read_only_automatic_suffix") }

    static var assignedAutomatically: String { text("ui.assigned_automatically") }

    static var loadingCategories: String { text("ui.loading_categories") }

    static var newCategory: String { text("ui.new_category") }

    static var confirmDeleteCategory: String { text("ui.confirm_delete_category") }

    static var deleteCategory: String { text("ui.delete_category") }

    static var thisCategoryWillStopBeingAvailableToYouAndYourFriendsExistingReviewsWillKeepTheirHistory: String { text("ui.this_category_will_stop_being_available_to_you_and_your_friends_existing_reviews_will_keep_their_history") }

    static var couldnTUpdateCategories: String { text("ui.couldn_t_update_categories") }

    static var defaultCategories: String { text("ui.default_categories") }

    static var noDefaultCategoriesAreAvailableYet: String { text("ui.no_default_categories_are_available_yet") }

    static var hide: String { text("ui.hide") }

    static var myCategories: String { text("ui.my_categories") }

    static var createYourOwnCategoriesToOrganizePlacesYourWay: String { text("ui.create_your_own_categories_to_organize_places_your_way") }

    static var createdByYou: String { text("ui.created_by_you") }

    static var addedFromFriends: String { text("ui.added_from_friends") }

    static var categoriesYouAddFromFriendsWillAppearHere: String { text("ui.categories_you_add_from_friends_will_appear_here") }

    static var categoriesFromFriends: String { text("ui.categories_from_friends") }

    static var friendCategoriesYouHavenTAddedYetWillShowUpHere: String { text("ui.friend_categories_you_haven_t_added_yet_will_show_up_here") }

    static var hiddenDefaultCategories: String { text("ui.hidden_default_categories") }

    static var defaultCategoriesYouHideWillAppearHereSoYouCanRestoreThemLater: String { text("ui.default_categories_you_hide_will_appear_here_so_you_can_restore_them_later") }

    static var hiddenOnlyForYou: String { text("ui.hidden_only_for_you") }

    static var show: String { text("ui.show") }

    static var edit: String { text("ui.edit") }

    static func editValue(_ value1: String) -> String {
        format("ui.edit_value", value1)
    }

    static var delete: String { text("ui.delete") }

    static func deleteValue(_ value1: String) -> String {
        format("ui.delete_value", value1)
    }

    static func categoryActionsForValue(_ value1: String) -> String {
        format("ui.category_actions_for_value", value1)
    }

    static func addedFromValue(_ value1: String) -> String {
        format("ui.added_from_value", value1)
    }

    static var addedFromAFriend: String { text("ui.added_from_a_friend") }

    static func createdByValue(_ value1: String) -> String {
        format("ui.created_by_value", value1)
    }

    static var createdByAFriend: String { text("ui.created_by_a_friend") }

    static var editCategory: String { text("ui.edit_category") }

    static var create: String { text("ui.create") }

    static var customCategoriesCanBeDiscoveredAndAddedByYourFriends: String { text("ui.custom_categories_can_be_discovered_and_added_by_your_friends") }

    static var changesApplyForEveryoneWhoHasAddedThisCategory: String { text("ui.changes_apply_for_everyone_who_has_added_this_category") }

    static var name: String { text("ui.name") }

    static var categoryNameMustBe120CharactersOrFewer: String { text("ui.category_name_must_be_120_characters_or_fewer") }

    static var noRatedPlacesMessage: String { text("ui.no_rated_places_message") }

    static var noReviewedDishesMessage: String { text("ui.no_reviewed_dishes_message") }

    static func valueHasNotRatedAnyPlacesYet(_ value1: String) -> String {
        format("ui.value_has_not_rated_any_places_yet", value1)
    }

    static func valueHasNotReviewedAnyDishesYet(_ value1: String) -> String {
        format("ui.value_has_not_reviewed_any_dishes_yet", value1)
    }

    static var friendsOnly: String { text("ui.friends_only") }

    static var onlyMe: String { text("ui.only_me") }

    static var selectASupportedImageBeforeUploading: String { text("ui.select_a_supported_image_before_uploading") }

    static var theReviewCouldNotBeSavedBecauseAtLeastOnePhotoFailedToUploadNothingWasChanged: String { text("ui.the_review_could_not_be_saved_because_at_least_one_photo_failed_to_upload_nothing_was_changed") }

    static var unableToSaveReview: String { text("ui.unable_to_save_review") }

    static var unableToDeleteReview: String { text("ui.unable_to_delete_review") }

    static var noReviewExistsForThisPlaceYet: String { text("ui.no_review_exists_for_this_place_yet") }

    static var placeName: String { text("ui.place_name") }

    static var review: String { text("ui.review") }

    static var descriptionOptional: String { text("ui.description_optional") }

    static var chooseAnActiveCategoryBeforeSaving: String { text("ui.choose_an_active_category_before_saving") }

    static var photos: String { text("ui.photos") }

    static var addPhotos: String { text("ui.add_photos") }

    static var newPhotos: String { text("ui.new_photos") }

    static var deleteReview: String { text("ui.delete_review") }

    static var deleteThisReview: String { text("ui.delete_this_review") }

    static var theCapturedPhotoCouldnTBePrepared: String { text("ui.the_captured_photo_couldn_t_be_prepared") }

    static var theSelectedPhotosCouldnTBePrepared: String { text("ui.the_selected_photos_couldn_t_be_prepared") }

    static var photoLibrary: String { text("ui.photo_library") }

    static var camera: String { text("ui.camera") }

    static var files: String { text("ui.files") }

    static var blockUser: String { text("ui.block_user") }

    static var profileActions: String { text("ui.profile_actions") }

    static func blockValue(_ value1: String) -> String {
        format("ui.block_value", value1)
    }

    static var youWonTSeeEachOtherSContentOrReceiveFriendRequestsYourFriendshipWillBeRemoved: String { text("ui.you_won_t_see_each_other_s_content_or_receive_friend_requests_your_friendship_will_be_removed") }

    static var couldnTBlockUser: String { text("ui.couldn_t_block_user") }

    static var pleaseTryAgain: String { text("ui.please_try_again") }

    static var loadingBlockedUsers: String { text("ui.loading_blocked_users") }

    static var noBlockedUsers: String { text("ui.no_blocked_users") }

    static var peopleYouBlockWillAppearHere: String { text("ui.people_you_block_will_appear_here") }

    static var unblock: String { text("ui.unblock") }

    static func unblockValue(_ value1: String) -> String {
        format("ui.unblock_value", value1)
    }

    static var blockedUsers: String { text("ui.blocked_users") }

    static func confirmUnblockUser(_ value1: String) -> String {
        format("ui.confirm_unblock_user", value1)
    }

    static var thisAllowsYouToSeeEachOtherSContentAgainYourPreviousFriendshipWonTBeRestored: String { text("ui.this_allows_you_to_see_each_other_s_content_again_your_previous_friendship_won_t_be_restored") }

    static var couldnTUpdateBlockedUsers: String { text("ui.couldn_t_update_blocked_users") }

    static var couldnTReportReview: String { text("ui.couldn_t_report_review") }

    static var reportSubmitted: String { text("ui.report_submitted") }

    static var reportReview: String { text("ui.report_review") }

    static var reportThisReview: String { text("ui.report_this_review") }

    static var theReviewAndItsPhotosWillBeSentToTrustmapForModeration: String { text("ui.the_review_and_its_photos_will_be_sent_to_trustmap_for_moderation") }

    static var yourReportHasBeenReceivedForReview: String { text("ui.your_report_has_been_received_for_review") }

    static func versionValueValue(_ value1: String, _ value2: String) -> String {
        format("ui.version_value_value", value1, value2)
    }

    static var restricted: String { text("ui.restricted") }

    static var couldnTDeleteYourAccountPleaseCheckYourConnectionAndTryAgain: String { text("ui.couldn_t_delete_your_account_please_check_your_connection_and_try_again") }

    static var privacySettingsAreNotAvailableOnThisServerVersion: String { text("ui.privacy_settings_are_not_available_on_this_server_version") }

    static var couldnTUpdatePrivacySettingsPleaseTryAgain: String { text("ui.couldn_t_update_privacy_settings_please_try_again") }

    static var unknownError: String { text("ui.unknown_error") }

    static var account: String { text("ui.account") }

    static var accountManagement: String { text("ui.account_management") }

    static var signOut: String { text("ui.sign_out") }

    static var confirmSignOut: String { text("ui.confirm_sign_out") }

    static var areYouSureYouWantToSignOut: String { text("ui.are_you_sure_you_want_to_sign_out") }

    static var deletingAccount: String { text("ui.deleting_account") }

    static var deleteAccount: String { text("ui.delete_account") }

    static var confirmDeleteAccount: String { text("ui.confirm_delete_account") }

    static var thisPermanentlyRemovesYourProfileReviewsPhotosFriendsAndPrivateCustomPlacesThatNoOneElseUsesT: String { text("ui.this_permanently_removes_your_profile_reviews_photos_friends_and_private_custom_places_that_no_one_else_uses_t") }

    static var permissions: String { text("ui.permissions") }

    static var locationAccess: String { text("ui.location_access") }

    static var friendsList: String { text("ui.friends_list") }

    static var privacy: String { text("ui.privacy") }

    static var defaultMapStyle: String { text("ui.default_map_style") }

    static var mapDiscovery: String { text("ui.map_discovery") }

    static var appearance: String { text("ui.appearance") }

    static var theme: String { text("ui.theme") }

    static var about: String { text("ui.about") }

    static var build: String { text("ui.build") }

    static var termsOfService: String { text("ui.terms_of_service") }

    static var reviewedByYou: String { text("ui.reviewed_by_you") }

    static func reviewedByValue(_ value1: String) -> String {
        format("ui.reviewed_by_value", value1)
    }

    static var reviewPhoto: String { text("ui.review_photo") }

    static func reviewPhotoValueOfValue(_ value1: String, _ value2: String) -> String {
        format("ui.review_photo_value_of_value", value1, value2)
    }

    static func valueOfValue(_ value1: String, _ value2: String) -> String {
        format("ui.value_of_value", value1, value2)
    }

    static func photoValueOfValue(_ value1: String, _ value2: String) -> String {
        format("ui.photo_value_of_value", value1, value2)
    }

    static func ratingValueOutOf5(_ value1: String) -> String {
        format("ui.rating_value_out_of_5", value1)
    }

    static var noRatingSelected: String { text("ui.no_rating_selected") }

    static var thePhotoResponseWasInvalid: String { text("ui.the_photo_response_was_invalid") }

    static var unableToLoadTheSelectedPhoto: String { text("ui.unable_to_load_the_selected_photo") }

    static var thePhotoDataWasInvalid: String { text("ui.the_photo_data_was_invalid") }

    static var opensThisUserSProfile: String { text("ui.opens_this_user_s_profile") }

    static var addressUnavailable: String { text("ui.address_unavailable") }

    static var mineOnly: String { text("ui.mine_only") }

    static var mineAndFriends: String { text("ui.mine_and_friends") }

    static func valueUnreadNotifications(_ value1: String) -> String {
        format("ui.value_unread_notifications", value1)
    }

    static var toDisconnectSignInWithAppleOpenSettingsYourNameSignInWithAppleTrustmapThenTapDeleteAndConfi: String { text("ui.to_disconnect_sign_in_with_apple_open_settings_your_name_sign_in_with_apple_trustmap_then_tap_delete_and_confi") }

    static var trustmapCouldNotReadTheAppleSignInResponse: String { text("ui.trustmap_could_not_read_the_apple_sign_in_response") }

    static var dishReviewDetailsWereSavedButTrustmapCouldNotFinishThePhotoChangesRefreshThePlaceAndTryAgain: String { text("ui.dish_review_details_were_saved_but_trustmap_could_not_finish_the_photo_changes_refresh_the_place_and_try_again") }

    static var trustmapCouldNotDetermineTheCurrentLocationPermissionState: String { text("ui.trustmap_could_not_determine_the_current_location_permission_state") }

    static var trustmapCouldNotRequestYourCurrentLocation: String { text("ui.trustmap_could_not_request_your_current_location") }

    static var trustmapCouldNotDetermineYourCurrentLocation: String { text("ui.trustmap_could_not_determine_your_current_location") }

    static var trustmapCouldNotDetermineLocationAccess: String { text("ui.trustmap_could_not_determine_location_access") }

    static func valueRatedPlaces(_ value1: String) -> String {
        format("ui.value_rated_places", value1)
    }

    static func valueReviewedDishes(_ value1: String) -> String {
        format("ui.value_reviewed_dishes", value1)
    }

    static func valueRatingValueValue(_ value1: String, _ value2: String, _ value3: String) -> String {
        format("ui.value_rating_value_value", value1, value2, value3)
    }

    static func valueValueRatingValueValue(_ value1: String, _ value2: String, _ value3: String, _ value4: String) -> String {
        format("ui.value_value_rating_value_value", value1, value2, value3, value4)
    }

    static var trustmapMember: String { text("ui.trustmap_member") }

    static var reviewDetailsWereSavedButTrustmapCouldNotFinishThePhotoChangesRefreshThePlaceAndTryAgain: String { text("ui.review_details_were_saved_but_trustmap_could_not_finish_the_photo_changes_refresh_the_place_and_try_again") }

    static func valueOutOfValue(_ value1: String, _ value2: String) -> String {
        format("ui.value_out_of_value", value1, value2)
    }

    static func valueValueReviewed(_ value1: String, _ value2: String) -> String {
        format("ui.value_value_reviewed", value1, value2)
    }

    static var aZ: String { text("ui.a_z") }

    static var ok: String { text("ui.ok") }

    /// Foundation supplies language-specific units and inflection, including VoiceOver copy.
    static func relativeTime(_ date: Date, abbreviated: Bool = true) -> String {
        guard Date.now.timeIntervalSince(date) >= 60 else { return justNow }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = abbreviated ? .abbreviated : .full
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    static func reviewCount(_ count: Int) -> String { format("count.reviews", count) }
    static func starCount(_ count: Int) -> String { format("count.stars", count) }
    static func pendingRequests(_ count: Int) -> String { format("count.pending_requests", count) }
    static func contributorsReviewed(_ count: Int) -> String { format("count.contributors_reviewed", count) }
    static func otherContributorsReviewed(_ name: String, _ count: Int) -> String {
        format("count.other_contributors_reviewed", name, count)
    }
    static var restaurants: String { text("category.restaurants") }
    static func friendsCount(_ value: String) -> String { format("profile.friends_count", value) }

    /// Match the server's English copy using the English catalog, never user-generated content.
    /// Raw error messages remain available to callers that classify errors by their content.
    private static let backendMessageKeys: [String: String] = {
        guard let url = resourceBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "en.lproj"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return [:]
        }
        return Dictionary(values.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
    }()

    static func backendMessage(_ message: String, in localizationBundle: Bundle? = nil) -> String {
        message.components(separatedBy: "\n").map { line in
            guard let key = backendMessageKeys[line] else { return line }
            return (localizationBundle ?? resourceBundle).localizedString(forKey: key, value: nil, table: "Localizable")
        }.joined(separator: "\n")
    }

    static var welcomeExampleReview: String { text("welcome.example_review") }
    static func trustedByFriends(_ count: Int) -> String { format("welcome.trusted_by_friends", count) }
}
