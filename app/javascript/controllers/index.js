import { application } from "./application"
import AuthSubmitController from "./auth_submit_controller"
import AutodetectionUploadController from "./autodetection_upload_controller"
import CarRemovalController from "./car_removal_controller"
import ClipboardController from "./clipboard_controller"
import ColorDetectorController from "./color_detector_controller"
import DetectedItemController from "./detected_item_controller"
import ExportRefreshController from "./export_refresh_controller"
import HelloController from "./hello_controller"
import ImageCropperController from "./image_cropper_controller"
import InfiniteScrollController from "./infinite_scroll_controller"
import ManualSelectionController from "./manual_selection_controller"
import ModalFrameController from "./modal_frame_controller"
import PhotoLightboxController from "./photo_lightbox_controller"
import PhotoUploadController from "./photo_upload_controller"
import PasswordVisibilityController from "./password_visibility_controller"
import PollController from "./poll_controller"
import SearchFormController from "./search_form_controller"
import SelectionAdjustmentController from "./selection_adjustment_controller"
import ThemeController from "./theme_controller"
import ToastController from "./toast_controller"
import ViewToggleController from "./view_toggle_controller"

application.register("auth-submit", AuthSubmitController)
application.register("autodetection-upload", AutodetectionUploadController)
application.register("car-removal", CarRemovalController)
application.register("clipboard", ClipboardController)
application.register("color-detector", ColorDetectorController)
application.register("detected-item", DetectedItemController)
application.register("export-refresh", ExportRefreshController)
application.register("hello", HelloController)
application.register("image-cropper", ImageCropperController)
application.register("infinite-scroll", InfiniteScrollController)
application.register("manual-selection", ManualSelectionController)
application.register("modal-frame", ModalFrameController)
application.register("photo-lightbox", PhotoLightboxController)
application.register("photo-upload", PhotoUploadController)
application.register("password-visibility", PasswordVisibilityController)
application.register("poll", PollController)
application.register("search-form", SearchFormController)
application.register("selection-adjustment", SelectionAdjustmentController)
application.register("theme", ThemeController)
application.register("toast", ToastController)
application.register("view-toggle", ViewToggleController)
