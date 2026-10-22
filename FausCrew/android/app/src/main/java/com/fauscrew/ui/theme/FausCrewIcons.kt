package com.fauscrew.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.Assignment
import androidx.compose.material.icons.automirrored.rounded.FormatAlignLeft
import androidx.compose.material.icons.automirrored.rounded.Help
import androidx.compose.material.icons.automirrored.rounded.InsertDriveFile
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.outlined.Campaign
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowCircleRight
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Badge
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Cake
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Campaign
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.Email
import androidx.compose.material.icons.rounded.GroupAdd
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PersonOff
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.RemoveCircle
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Security
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.WatchLater
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Apartment
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Collections
import androidx.compose.material.icons.rounded.PersonRemove
import androidx.compose.material.icons.rounded.PersonAddAlt
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.IosShare
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.GppBad
import androidx.compose.material.icons.rounded.GppGood
import androidx.compose.material.icons.rounded.FormatQuote
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * One place that maps the SF Symbols used by the SwiftUI views to their closest Material
 * glyphs. Names follow the iOS symbol so Compose code reads like the SwiftUI reference.
 */
internal object FausCrewIcons {
    val personFill: ImageVector = Icons.Rounded.Person
    val houseFill: ImageVector = Icons.Rounded.Home
    val gameControllerFill: ImageVector = Icons.Rounded.SportsEsports
    val chevronUp: ImageVector = Icons.Rounded.KeyboardArrowUp
    val chevronDown: ImageVector = Icons.Rounded.KeyboardArrowDown
    val chevronRight: ImageVector = Icons.AutoMirrored.Rounded.KeyboardArrowRight
    val megaphoneFill: ImageVector = Icons.Rounded.Campaign
    val megaphone: ImageVector = Icons.Outlined.Campaign
    val listClipboardFill: ImageVector = Icons.AutoMirrored.Rounded.Assignment
    val person3Fill: ImageVector = Icons.Rounded.Groups
    val plus: ImageVector = Icons.Rounded.Add
    val minus: ImageVector = Icons.Rounded.Remove
    val xmark: ImageVector = Icons.Rounded.Close
    val checkmark: ImageVector = Icons.Rounded.Check
    val checkmarkCircleFill: ImageVector = Icons.Rounded.CheckCircle
    val checkmarkSealFill: ImageVector = Icons.Rounded.Verified
    val xmarkCircleFill: ImageVector = Icons.Rounded.Cancel
    val minusCircleFill: ImageVector = Icons.Rounded.RemoveCircle
    val circle: ImageVector = Icons.Rounded.RadioButtonUnchecked
    val docFill: ImageVector = Icons.AutoMirrored.Rounded.InsertDriveFile
    val arrowRightCircleFill: ImageVector = Icons.Rounded.ArrowCircleRight
    val magnifyingGlass: ImageVector = Icons.Rounded.Search
    val arrowRight: ImageVector = Icons.AutoMirrored.Rounded.ArrowForward
    val arrowClockwise: ImageVector = Icons.Rounded.Refresh
    val arrowTriangle2Circlepath: ImageVector = Icons.Rounded.Sync
    val textBadgeCheckmark: ImageVector = Icons.Rounded.Checklist
    val pencil: ImageVector = Icons.Rounded.Edit
    val pencilCircleFill: ImageVector = Icons.Rounded.EditNote
    val textAlignLeft: ImageVector = Icons.AutoMirrored.Rounded.FormatAlignLeft
    val textFormat: ImageVector = Icons.Rounded.TextFields
    val paperplaneFill: ImageVector = Icons.AutoMirrored.Rounded.Send
    val sparkles: ImageVector = Icons.Rounded.AutoAwesome
    val calendar: ImageVector = Icons.Rounded.CalendarMonth
    val clock: ImageVector = Icons.Rounded.Schedule
    val clockFill: ImageVector = Icons.Rounded.WatchLater
    val personCropCircleFill: ImageVector = Icons.Rounded.AccountCircle
    val personCropCircleBadgeExclamationmark: ImageVector = Icons.Rounded.PersonOff
    val leafFill: ImageVector = Icons.Rounded.Eco
    val flameFill: ImageVector = Icons.Rounded.LocalFireDepartment
    val boltFill: ImageVector = Icons.Rounded.Bolt
    val personTextRectangleFill: ImageVector = Icons.Rounded.Badge
    val envelopeFill: ImageVector = Icons.Rounded.Email
    val phoneFill: ImageVector = Icons.Rounded.Phone
    val gearshapeFill: ImageVector = Icons.Rounded.Settings
    val bellBadgeFill: ImageVector = Icons.Rounded.NotificationsActive
    val lockShieldFill: ImageVector = Icons.Rounded.Security
    val questionmarkCircleFill: ImageVector = Icons.AutoMirrored.Rounded.Help
    val globeFill: ImageVector = Icons.Rounded.Public
    val infoCircleFill: ImageVector = Icons.Rounded.Info
    val logout: ImageVector = Icons.AutoMirrored.Rounded.Logout
    val person2BadgePlus: ImageVector = Icons.Rounded.GroupAdd
    val birthdayCakeFill: ImageVector = Icons.Rounded.Cake
    val exclamationmarkTriangleFill: ImageVector = Icons.Rounded.Warning
    val chevronLeft: ImageVector = Icons.Rounded.ChevronLeft
    val arrowLeft: ImageVector = Icons.AutoMirrored.Rounded.ArrowBack
    val flag: ImageVector = Icons.Rounded.Flag
    val checkmarkShieldFill: ImageVector = Icons.Rounded.GppGood
    val exclamationmarkShieldFill: ImageVector = Icons.Rounded.GppBad
    /** SF `quote.closing`; `quote.opening` is the same glyph rotated 180°. */
    val quoteClosing: ImageVector = Icons.Rounded.FormatQuote
    val heartFill: ImageVector = Icons.Rounded.Favorite

    val chevronRightSmall: ImageVector = Icons.Rounded.ChevronRight
    val graduationcapFill: ImageVector = Icons.Rounded.School
    val building2Fill: ImageVector = Icons.Rounded.Apartment
    val person2Fill: ImageVector = Icons.Rounded.Group
    val sliderHorizontal3: ImageVector = Icons.Rounded.Tune
    val photoOnRectangle: ImageVector = Icons.Rounded.Collections
    val personFillXmark: ImageVector = Icons.Rounded.PersonRemove
    val personBadgePlus: ImageVector = Icons.Rounded.PersonAddAlt
    val keyFill: ImageVector = Icons.Rounded.Key
    val docOnDoc: ImageVector = Icons.Rounded.ContentCopy
    val squareAndArrowUp: ImageVector = Icons.Rounded.IosShare
    val starFill: ImageVector = Icons.Rounded.Star
    val lockShield: ImageVector = Icons.Rounded.Shield

    /** SF `crown.fill`; Material has no crown, so the silhouette is drawn here. */
    val crownFill: ImageVector by lazy {
        ImageVector.Builder("crownFill", 24.dp, 24.dp, 24f, 24f).path(fill = SolidColor(Color.Black)) {
            moveTo(3f, 7f)
            lineTo(7.5f, 10.5f)
            lineTo(12f, 4f)
            lineTo(16.5f, 10.5f)
            lineTo(21f, 7f)
            lineTo(19f, 17f)
            lineTo(5f, 17f)
            close()
            moveTo(5f, 18.5f)
            lineTo(19f, 18.5f)
            lineTo(19f, 20.5f)
            lineTo(5f, 20.5f)
            close()
        }.build()
    }
}
