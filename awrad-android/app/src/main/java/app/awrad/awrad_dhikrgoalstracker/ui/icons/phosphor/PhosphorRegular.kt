package app.awrad.awrad_dhikrgoalstracker.ui.icons.phosphor

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * Phosphor Icons — Regular weight.
 *
 * Source: https://phosphoricons.com (MIT)
 * Paths match Phosphor core regular assets.
 *
 * Add icons here as needed rather than bundling the full pack.
 */
object PhosphorRegular {

    val Bell: ImageVector
        get() {
            if (_bell != null) return _bell!!
            _bell = ImageVector.Builder(
                name = "PhosphorRegular.Bell",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(221.8f, 175.94f)
                    curveTo(216.25f, 166.38f, 208f, 139.33f, 208f, 104f)
                    arcToRelative(80f, 80f, 0f, true, false, -160f, 0f)
                    curveTo(48f, 139.34f, 39.74f, 166.38f, 34.19f, 175.94f)
                    arcTo(16f, 16f, 0f, false, false, 48f, 200f)
                    horizontalLineTo(88.81f)
                    arcToRelative(40f, 40f, 0f, false, false, 78.38f, 0f)
                    horizontalLineTo(208f)
                    arcToRelative(16f, 16f, 0f, false, false, 13.8f, -24.06f)
                    close()
                    moveTo(128f, 216f)
                    arcToRelative(24f, 24f, 0f, false, true, -22.62f, -16f)
                    horizontalLineTo(150.62f)
                    arcTo(24f, 24f, 0f, false, true, 128f, 216f)
                    close()
                    moveTo(48f, 184f)
                    curveTo(55.7f, 170.76f, 64f, 140.08f, 64f, 104f)
                    arcToRelative(64f, 64f, 0f, true, true, 128f, 0f)
                    curveTo(192f, 140.05f, 200.28f, 170.73f, 208f, 184f)
                    close()
                }
            }.build()
            return _bell!!
        }

    val ChatsCircle: ImageVector
        get() {
            if (_chatsCircle != null) return _chatsCircle!!
            _chatsCircle = ImageVector.Builder(
                name = "PhosphorRegular.ChatsCircle",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(232.07f, 186.76f)
                    arcToRelative(80f, 80f, 0f, false, false, -62.5f, -114.17f)
                    arcTo(80f, 80f, 0f, true, false, 23.93f, 138.76f)
                    lineTo(16.66f, 163.47f)
                    arcToRelative(16f, 16f, 0f, false, false, 19.87f, 19.87f)
                    lineTo(61.24f, 176.07f)
                    arcToRelative(80.39f, 80.39f, 0f, false, false, 25.18f, 7.35f)
                    arcToRelative(80f, 80f, 0f, false, false, 108.34f, 40.65f)
                    lineTo(219.47f, 231.34f)
                    arcToRelative(16f, 16f, 0f, false, false, 19.87f, -19.86f)
                    close()
                    moveTo(62f, 159.5f)
                    arcToRelative(8.28f, 8.28f, 0f, false, false, -2.26f, 0.32f)
                    lineTo(32f, 168f)
                    lineTo(40.17f, 140.24f)
                    arcToRelative(8f, 8f, 0f, false, false, -0.63f, -6f)
                    arcToRelative(64f, 64f, 0f, true, true, 26.26f, 26.26f)
                    arcTo(8f, 8f, 0f, false, false, 62f, 159.5f)
                    close()
                    moveTo(215.79f, 188.23f)
                    lineTo(224f, 216f)
                    lineTo(196.24f, 207.83f)
                    arcToRelative(8f, 8f, 0f, false, false, -6f, 0.63f)
                    arcToRelative(64.05f, 64.05f, 0f, false, true, -85.87f, -24.88f)
                    arcTo(79.93f, 79.93f, 0f, false, false, 174.7f, 89.71f)
                    arcToRelative(64f, 64f, 0f, false, true, 41.75f, 92.48f)
                    arcTo(8f, 8f, 0f, false, false, 215.82f, 188.23f)
                    close()
                }
            }.build()
            return _chatsCircle!!
        }

    val ArrowsClockwise: ImageVector
        get() {
            if (_arrowsClockwise != null) return _arrowsClockwise!!
            _arrowsClockwise = ImageVector.Builder(
                name = "PhosphorRegular.ArrowsClockwise",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(224f, 48f)
                    verticalLineTo(96f)
                    arcToRelative(8f, 8f, 0f, false, true, -8f, 8f)
                    horizontalLineTo(168f)
                    arcToRelative(8f, 8f, 0f, false, true, 0f, -16f)
                    horizontalLineTo(196.69f)
                    lineTo(182.06f, 73.37f)
                    arcToRelative(79.56f, 79.56f, 0f, false, false, -56.13f, -23.43f)
                    horizontalLineTo(125.48f)
                    arcTo(79.52f, 79.52f, 0f, false, false, 69.59f, 72.71f)
                    arcTo(8f, 8f, 0f, false, true, 58.41f, 61.27f)
                    arcToRelative(96f, 96f, 0f, false, true, 135f, 0.79f)
                    lineTo(208f, 76.69f)
                    verticalLineTo(48f)
                    arcToRelative(8f, 8f, 0f, false, true, 16f, 0f)
                    close()
                    moveTo(186.41f, 183.29f)
                    arcToRelative(80f, 80f, 0f, false, true, -112.47f, -0.66f)
                    lineTo(59.31f, 168f)
                    horizontalLineTo(88f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, -16f)
                    horizontalLineTo(40f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, 8f)
                    verticalLineTo(208f)
                    arcToRelative(8f, 8f, 0f, false, false, 16f, 0f)
                    verticalLineTo(179.31f)
                    lineTo(62.63f, 193.94f)
                    arcTo(95.43f, 95.43f, 0f, false, false, 130f, 222.06f)
                    horizontalLineTo(130.53f)
                    arcToRelative(95.36f, 95.36f, 0f, false, false, 67.07f, -27.33f)
                    arcToRelative(8f, 8f, 0f, false, false, -11.18f, -11.44f)
                    close()
                }
            }.build()
            return _arrowsClockwise!!
        }

    val Target: ImageVector
        get() {
            if (_target != null) return _target!!
            _target = ImageVector.Builder(
                name = "PhosphorRegular.Target",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(221.87f, 83.16f)
                    arcTo(104.1f, 104.1f, 0f, true, true, 195.67f, 49f)
                    lineTo(218.34f, 26.32f)
                    arcToRelative(8f, 8f, 0f, false, true, 11.32f, 11.32f)
                    lineTo(133.66f, 133.64f)
                    arcToRelative(8f, 8f, 0f, false, true, -11.32f, -11.32f)
                    lineTo(150.06f, 94.6f)
                    arcToRelative(40f, 40f, 0f, true, false, 17.87f, 31.09f)
                    arcToRelative(8f, 8f, 0f, true, true, 16f, -0.9f)
                    arcToRelative(56f, 56f, 0f, true, true, -22.38f, -41.65f)
                    lineTo(184.3f, 60.39f)
                    arcToRelative(87.88f, 87.88f, 0f, true, false, 23.13f, 29.67f)
                    arcToRelative(8f, 8f, 0f, false, true, 14.44f, -6.9f)
                    close()
                }
            }.build()
            return _target!!
        }

    val Clock: ImageVector
        get() {
            if (_clock != null) return _clock!!
            _clock = ImageVector.Builder(
                name = "PhosphorRegular.Clock",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(128f, 24f)
                    arcTo(104f, 104f, 0f, true, false, 232f, 128f)
                    arcTo(104.11f, 104.11f, 0f, false, false, 128f, 24f)
                    close()
                    moveTo(128f, 216f)
                    arcToRelative(88f, 88f, 0f, true, true, 88f, -88f)
                    arcTo(88.1f, 88.1f, 0f, false, true, 128f, 216f)
                    close()
                    moveTo(192f, 128f)
                    arcToRelative(8f, 8f, 0f, false, true, -8f, 8f)
                    horizontalLineTo(128f)
                    arcToRelative(8f, 8f, 0f, false, true, -8f, -8f)
                    verticalLineTo(72f)
                    arcToRelative(8f, 8f, 0f, false, true, 16f, 0f)
                    verticalLineTo(120f)
                    horizontalLineTo(184f)
                    arcTo(8f, 8f, 0f, false, true, 192f, 128f)
                    close()
                }
            }.build()
            return _clock!!
        }

    val User: ImageVector
        get() {
            if (_user != null) return _user!!
            _user = ImageVector.Builder(
                name = "PhosphorRegular.User",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(230.92f, 212f)
                    curveTo(215.69f, 185.67f, 192.22f, 166.79f, 164.83f, 157.84f)
                    arcToRelative(72f, 72f, 0f, true, false, -73.66f, 0f)
                    curveTo(63.78f, 166.78f, 40.31f, 185.66f, 25.08f, 212f)
                    arcToRelative(8f, 8f, 0f, true, false, 13.85f, 8f)
                    curveTo(57.77f, 187.44f, 91.07f, 168f, 128f, 168f)
                    curveTo(164.93f, 168f, 198.23f, 187.44f, 217.07f, 220f)
                    arcToRelative(8f, 8f, 0f, true, false, 13.85f, -8f)
                    close()
                    moveTo(72f, 96f)
                    arcToRelative(56f, 56f, 0f, true, true, 56f, 56f)
                    arcTo(56.06f, 56.06f, 0f, false, true, 72f, 96f)
                    close()
                }
            }.build()
            return _user!!
        }

    val Rss: ImageVector
        get() {
            if (_rss != null) return _rss!!
            _rss = ImageVector.Builder(
                name = "PhosphorRegular.Rss",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(106.91f, 149.09f)
                    arcTo(71.53f, 71.53f, 0f, false, true, 128f, 200f)
                    arcToRelative(8f, 8f, 0f, false, true, -16f, 0f)
                    arcToRelative(56f, 56f, 0f, false, false, -56f, -56f)
                    arcToRelative(8f, 8f, 0f, false, true, 0f, -16f)
                    arcTo(71.53f, 71.53f, 0f, false, true, 106.91f, 149.09f)
                    close()
                    moveTo(56f, 80f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, 16f)
                    arcTo(104f, 104f, 0f, false, true, 160f, 200f)
                    arcToRelative(8f, 8f, 0f, false, false, 16f, 0f)
                    arcTo(120f, 120f, 0f, false, false, 56f, 80f)
                    close()
                    moveTo(174.79f, 81.21f)
                    arcTo(166.9f, 166.9f, 0f, false, false, 56f, 32f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, 16f)
                    arcTo(151f, 151f, 0f, false, true, 163.48f, 92.52f)
                    arcTo(151f, 151f, 0f, false, true, 208f, 200f)
                    arcToRelative(8f, 8f, 0f, false, false, 16f, 0f)
                    arcTo(166.9f, 166.9f, 0f, false, false, 174.79f, 81.21f)
                    close()
                    moveTo(60f, 184f)
                    arcToRelative(12f, 12f, 0f, true, false, 12f, 12f)
                    arcTo(12f, 12f, 0f, false, false, 60f, 184f)
                    close()
                }
            }.build()
            return _rss!!
        }

    val Trophy: ImageVector
        get() {
            if (_trophy != null) return _trophy!!
            _trophy = ImageVector.Builder(
                name = "PhosphorRegular.Trophy",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(232f, 64f)
                    horizontalLineTo(208f)
                    verticalLineTo(48f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, -8f)
                    horizontalLineTo(56f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, 8f)
                    verticalLineTo(64f)
                    horizontalLineTo(24f)
                    arcTo(16f, 16f, 0f, false, false, 8f, 80f)
                    verticalLineTo(96f)
                    arcToRelative(40f, 40f, 0f, false, false, 40f, 40f)
                    horizontalLineTo(51.65f)
                    arcTo(80.13f, 80.13f, 0f, false, false, 120f, 191.61f)
                    verticalLineTo(216f)
                    horizontalLineTo(96f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, 16f)
                    horizontalLineTo(160f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, -16f)
                    horizontalLineTo(136f)
                    verticalLineTo(191.58f)
                    curveTo(167.94f, 188.35f, 194.44f, 165.94f, 204.08f, 136f)
                    horizontalLineTo(208f)
                    arcToRelative(40f, 40f, 0f, false, false, 40f, -40f)
                    verticalLineTo(80f)
                    arcTo(16f, 16f, 0f, false, false, 232f, 64f)
                    close()
                    moveTo(48f, 120f)
                    arcTo(24f, 24f, 0f, false, true, 24f, 96f)
                    verticalLineTo(80f)
                    horizontalLineTo(48f)
                    verticalLineTo(112f)
                    quadTo(48f, 116f, 48.39f, 120f)
                    close()
                    moveTo(192f, 111.1f)
                    curveTo(192f, 146.62f, 163f, 175.74f, 128f, 176f)
                    arcToRelative(64f, 64f, 0f, false, true, -64f, -64f)
                    verticalLineTo(56f)
                    horizontalLineTo(192f)
                    close()
                    moveTo(232f, 96f)
                    arcToRelative(24f, 24f, 0f, false, true, -24f, 24f)
                    horizontalLineTo(207.5f)
                    arcToRelative(81.81f, 81.81f, 0f, false, false, 0.5f, -8.9f)
                    verticalLineTo(80f)
                    horizontalLineTo(232f)
                    close()
                }
            }.build()
            return _trophy!!
        }

    val UsersThree: ImageVector
        get() {
            if (_usersThree != null) return _usersThree!!
            _usersThree = ImageVector.Builder(
                name = "PhosphorRegular.UsersThree",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(244.8f, 150.4f)
                    arcToRelative(8f, 8f, 0f, false, true, -11.2f, -1.6f)
                    arcTo(51.6f, 51.6f, 0f, false, false, 192f, 128f)
                    arcToRelative(8f, 8f, 0f, false, true, -7.37f, -4.89f)
                    arcToRelative(8f, 8f, 0f, false, true, 0f, -6.22f)
                    arcTo(8f, 8f, 0f, false, true, 192f, 112f)
                    arcToRelative(24f, 24f, 0f, true, false, -23.24f, -30f)
                    arcToRelative(8f, 8f, 0f, true, true, -15.5f, -4f)
                    arcTo(40f, 40f, 0f, true, true, 219f, 117.51f)
                    arcToRelative(67.94f, 67.94f, 0f, false, true, 27.43f, 21.68f)
                    arcTo(8f, 8f, 0f, false, true, 244.8f, 150.4f)
                    close()
                    moveTo(190.92f, 212f)
                    arcToRelative(8f, 8f, 0f, true, true, -13.84f, 8f)
                    arcToRelative(57f, 57f, 0f, false, false, -98.16f, 0f)
                    arcToRelative(8f, 8f, 0f, true, true, -13.84f, -8f)
                    arcToRelative(72.06f, 72.06f, 0f, false, true, 33.74f, -29.92f)
                    arcToRelative(48f, 48f, 0f, true, true, 58.36f, 0f)
                    arcTo(72.06f, 72.06f, 0f, false, true, 190.92f, 212f)
                    close()
                    moveTo(128f, 176f)
                    arcToRelative(32f, 32f, 0f, true, false, -32f, -32f)
                    arcTo(32f, 32f, 0f, false, false, 128f, 176f)
                    close()
                    moveTo(72f, 120f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, -8f)
                    arcTo(24f, 24f, 0f, true, true, 87.24f, 82f)
                    arcToRelative(8f, 8f, 0f, true, false, 15.5f, -4f)
                    arcTo(40f, 40f, 0f, true, false, 37f, 117.51f)
                    arcTo(67.94f, 67.94f, 0f, false, false, 9.6f, 139.19f)
                    arcToRelative(8f, 8f, 0f, true, false, 12.8f, 9.61f)
                    arcTo(51.6f, 51.6f, 0f, false, true, 64f, 128f)
                    arcTo(8f, 8f, 0f, false, false, 72f, 120f)
                    close()
                }
            }.build()
            return _usersThree!!
        }

    val BookmarkSimple: ImageVector
        get() {
            if (_bookmarkSimple != null) return _bookmarkSimple!!
            _bookmarkSimple = ImageVector.Builder(
                name = "PhosphorRegular.BookmarkSimple",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(184f, 32f)
                    horizontalLineTo(72f)
                    arcTo(16f, 16f, 0f, false, false, 56f, 48f)
                    verticalLineTo(224f)
                    arcToRelative(8f, 8f, 0f, false, false, 12.24f, 6.78f)
                    lineTo(128f, 193.43f)
                    lineTo(187.77f, 230.78f)
                    arcTo(8f, 8f, 0f, false, false, 200f, 224f)
                    verticalLineTo(48f)
                    arcTo(16f, 16f, 0f, false, false, 184f, 32f)
                    close()
                    moveTo(184f, 209.57f)
                    lineTo(132.23f, 177.22f)
                    arcToRelative(8f, 8f, 0f, false, false, -8.48f, 0f)
                    lineTo(72f, 209.57f)
                    verticalLineTo(48f)
                    horizontalLineTo(184f)
                    close()
                }
            }.build()
            return _bookmarkSimple!!
        }

    val ChartBar: ImageVector
        get() {
            if (_chartBar != null) return _chartBar!!
            _chartBar = ImageVector.Builder(
                name = "PhosphorRegular.ChartBar",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(224f, 200f)
                    horizontalLineTo(216f)
                    verticalLineTo(40f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, -8f)
                    horizontalLineTo(152f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, 8f)
                    verticalLineTo(80f)
                    horizontalLineTo(96f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, 8f)
                    verticalLineTo(128f)
                    horizontalLineTo(48f)
                    arcToRelative(8f, 8f, 0f, false, false, -8f, 8f)
                    verticalLineTo(200f)
                    horizontalLineTo(32f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, 16f)
                    horizontalLineTo(224f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, -16f)
                    close()
                    moveTo(160f, 48f)
                    horizontalLineTo(200f)
                    verticalLineTo(200f)
                    horizontalLineTo(160f)
                    close()
                    moveTo(104f, 96f)
                    horizontalLineTo(144f)
                    verticalLineTo(200f)
                    horizontalLineTo(104f)
                    close()
                    moveTo(56f, 144f)
                    horizontalLineTo(88f)
                    verticalLineTo(200f)
                    horizontalLineTo(56f)
                    close()
                }
            }.build()
            return _chartBar!!
        }

    val List: ImageVector
        get() {
            if (_list != null) return _list!!
            _list = ImageVector.Builder(
                name = "PhosphorRegular.List",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(224f, 128f)
                    arcToRelative(8f, 8f, 0f, false, true, -8f, 8f)
                    horizontalLineTo(40f)
                    arcToRelative(8f, 8f, 0f, false, true, 0f, -16f)
                    horizontalLineTo(216f)
                    arcTo(8f, 8f, 0f, false, true, 224f, 128f)
                    close()
                    moveTo(40f, 72f)
                    horizontalLineTo(216f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, -16f)
                    horizontalLineTo(40f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, 16f)
                    close()
                    moveTo(216f, 184f)
                    horizontalLineTo(40f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, 16f)
                    horizontalLineTo(216f)
                    arcToRelative(8f, 8f, 0f, false, false, 0f, -16f)
                    close()
                }
            }.build()
            return _list!!
        }

    val SealCheck: ImageVector
        get() {
            if (_sealCheck != null) return _sealCheck!!
            _sealCheck = ImageVector.Builder(
                name = "PhosphorRegular.SealCheck",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(225.86f, 102.82f)
                    curveTo(222.09f, 98.88f, 218.19f, 94.82f, 216.72f, 91.25f)
                    curveTo(215.36f, 87.98f, 215.28f, 82.56f, 215.2f, 77.31f)
                    curveTo(215.05f, 67.55f, 214.89f, 56.49f, 207.2f, 48.8f)
                    curveTo(199.51f, 41.11f, 188.45f, 40.95f, 178.69f, 40.8f)
                    curveTo(173.44f, 40.72f, 168.02f, 40.64f, 164.75f, 39.28f)
                    curveTo(161.19f, 37.81f, 157.12f, 33.91f, 153.18f, 30.14f)
                    curveTo(146.28f, 23.51f, 138.44f, 16f, 128f, 16f)
                    curveTo(117.56f, 16f, 109.73f, 23.51f, 102.82f, 30.14f)
                    curveTo(98.88f, 33.91f, 94.82f, 37.81f, 91.25f, 39.28f)
                    curveTo(88f, 40.64f, 82.56f, 40.72f, 77.31f, 40.8f)
                    curveTo(67.55f, 40.95f, 56.49f, 41.11f, 48.8f, 48.8f)
                    curveTo(41.11f, 56.49f, 41f, 67.55f, 40.8f, 77.31f)
                    curveTo(40.72f, 82.56f, 40.64f, 87.98f, 39.28f, 91.25f)
                    curveTo(37.81f, 94.81f, 33.91f, 98.88f, 30.14f, 102.82f)
                    curveTo(23.51f, 109.72f, 16f, 117.56f, 16f, 128f)
                    curveTo(16f, 138.44f, 23.51f, 146.27f, 30.14f, 153.18f)
                    curveTo(33.91f, 157.12f, 37.81f, 161.18f, 39.28f, 164.75f)
                    curveTo(40.64f, 168.02f, 40.72f, 173.44f, 40.8f, 178.69f)
                    curveTo(40.95f, 188.45f, 41.11f, 199.51f, 48.8f, 207.2f)
                    curveTo(56.49f, 214.89f, 67.55f, 215.05f, 77.31f, 215.2f)
                    curveTo(82.56f, 215.28f, 87.98f, 215.36f, 91.25f, 216.72f)
                    curveTo(94.81f, 218.19f, 98.88f, 222.09f, 102.82f, 225.86f)
                    curveTo(109.72f, 232.49f, 117.56f, 240f, 128f, 240f)
                    curveTo(138.44f, 240f, 146.27f, 232.49f, 153.18f, 225.86f)
                    curveTo(157.12f, 222.09f, 161.18f, 218.19f, 164.75f, 216.72f)
                    curveTo(168.02f, 215.36f, 173.44f, 215.28f, 178.69f, 215.2f)
                    curveTo(188.45f, 215.05f, 199.51f, 214.89f, 207.2f, 207.2f)
                    curveTo(214.89f, 199.51f, 215.05f, 188.45f, 215.2f, 178.69f)
                    curveTo(215.28f, 173.44f, 215.36f, 168.02f, 216.72f, 164.75f)
                    curveTo(218.19f, 161.19f, 222.09f, 157.12f, 225.86f, 153.18f)
                    curveTo(232.49f, 146.28f, 240f, 138.44f, 240f, 128f)
                    curveTo(240f, 117.56f, 232.49f, 109.73f, 225.86f, 102.82f)
                    close()
                    moveTo(214.31f, 142.11f)
                    curveTo(209.52f, 147.11f, 204.56f, 152.28f, 201.93f, 158.63f)
                    curveTo(199.41f, 164.73f, 199.3f, 171.7f, 199.2f, 178.45f)
                    curveTo(199.1f, 185.45f, 198.99f, 192.78f, 195.88f, 195.88f)
                    curveTo(192.77f, 198.98f, 185.49f, 199.1f, 178.45f, 199.2f)
                    curveTo(171.7f, 199.3f, 164.73f, 199.41f, 158.63f, 201.93f)
                    curveTo(152.28f, 204.56f, 147.11f, 209.52f, 142.11f, 214.31f)
                    curveTo(137.11f, 219.1f, 132f, 224f, 128f, 224f)
                    curveTo(124f, 224f, 118.85f, 219.08f, 113.89f, 214.31f)
                    curveTo(108.93f, 209.54f, 103.72f, 204.56f, 97.37f, 201.93f)
                    curveTo(91.27f, 199.41f, 84.3f, 199.3f, 77.55f, 199.2f)
                    curveTo(70.55f, 199.1f, 63.22f, 198.99f, 60.12f, 195.88f)
                    curveTo(57.02f, 192.77f, 56.9f, 185.49f, 56.8f, 178.45f)
                    curveTo(56.7f, 171.7f, 56.59f, 164.73f, 54.07f, 158.63f)
                    curveTo(51.44f, 152.28f, 46.48f, 147.11f, 41.69f, 142.11f)
                    curveTo(36.9f, 137.11f, 32f, 132f, 32f, 128f)
                    curveTo(32f, 124f, 36.92f, 118.85f, 41.69f, 113.89f)
                    curveTo(46.46f, 108.93f, 51.44f, 103.72f, 54.07f, 97.37f)
                    curveTo(56.59f, 91.27f, 56.7f, 84.3f, 56.8f, 77.55f)
                    curveTo(56.9f, 70.55f, 57.01f, 63.22f, 60.12f, 60.12f)
                    curveTo(63.23f, 57.02f, 70.51f, 56.9f, 77.55f, 56.8f)
                    curveTo(84.3f, 56.7f, 91.27f, 56.59f, 97.37f, 54.07f)
                    curveTo(103.72f, 51.44f, 108.89f, 46.48f, 113.89f, 41.69f)
                    curveTo(118.89f, 36.9f, 124f, 32f, 128f, 32f)
                    curveTo(132f, 32f, 137.15f, 36.92f, 142.11f, 41.69f)
                    curveTo(147.07f, 46.46f, 152.28f, 51.44f, 158.63f, 54.07f)
                    curveTo(164.73f, 56.59f, 171.7f, 56.7f, 178.45f, 56.8f)
                    curveTo(185.45f, 56.9f, 192.78f, 57.01f, 195.88f, 60.12f)
                    curveTo(198.98f, 63.23f, 199.1f, 70.51f, 199.2f, 77.55f)
                    curveTo(199.3f, 84.3f, 199.41f, 91.27f, 201.93f, 97.37f)
                    curveTo(204.56f, 103.72f, 209.52f, 108.89f, 214.31f, 113.89f)
                    curveTo(219.1f, 118.89f, 224f, 124f, 224f, 128f)
                    curveTo(224f, 132f, 219.08f, 137.15f, 214.31f, 142.11f)
                    close()
                    moveTo(173.66f, 98.34f)
                    arcToRelative(8f, 8f, 0f, false, true, 0f, 11.32f)
                    lineTo(117.66f, 165.66f)
                    arcToRelative(8f, 8f, 0f, false, true, -11.32f, 0f)
                    lineTo(82.34f, 141.66f)
                    arcToRelative(8f, 8f, 0f, false, true, 11.32f, -11.32f)
                    lineTo(112f, 148.69f)
                    lineTo(162.34f, 98.34f)
                    arcTo(8f, 8f, 0f, false, true, 173.66f, 98.34f)
                    close()
                }
            }.build()
            return _sealCheck!!
        }

    val Play: ImageVector
        get() {
            if (_play != null) return _play!!
            _play = ImageVector.Builder(
                name = "PhosphorRegular.Play",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(232.4f, 114.49f)
                    lineTo(88.32f, 26.35f)
                    arcToRelative(16f, 16f, 0f, false, false, -16.2f, -0.3f)
                    arcTo(15.86f, 15.86f, 0f, false, false, 64f, 39.87f)
                    verticalLineTo(216.13f)
                    arcTo(15.94f, 15.94f, 0f, false, false, 80f, 232f)
                    arcToRelative(16.07f, 16.07f, 0f, false, false, 8.36f, -2.35f)
                    lineTo(232.4f, 141.51f)
                    arcToRelative(15.81f, 15.81f, 0f, false, false, 0f, -27f)
                    close()
                    moveTo(80f, 215.94f)
                    verticalLineTo(40f)
                    lineTo(223.83f, 128f)
                    close()
                }
            }.build()
            return _play!!
        }

    val CaretRight: ImageVector
        get() {
            if (_caretRight != null) return _caretRight!!
            _caretRight = ImageVector.Builder(
                name = "PhosphorRegular.CaretRight",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(181.66f, 133.66f)
                    lineTo(101.66f, 213.66f)
                    arcToRelative(8f, 8f, 0f, false, true, -11.32f, -11.32f)
                    lineTo(164.69f, 128f)
                    lineTo(90.34f, 53.66f)
                    arcToRelative(8f, 8f, 0f, false, true, 11.32f, -11.32f)
                    lineTo(181.66f, 122.34f)
                    arcTo(8f, 8f, 0f, false, true, 181.66f, 133.66f)
                    close()
                }
            }.build()
            return _caretRight!!
        }

    val Heart: ImageVector
        get() {
            if (_heart != null) return _heart!!
            _heart = ImageVector.Builder(
                name = "PhosphorRegular.Heart",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(178f, 40f)
                    curveTo(157.35f, 40f, 139.27f, 48.88f, 128f, 63.89f)
                    curveTo(116.73f, 48.88f, 98.65f, 40f, 78f, 40f)
                    arcToRelative(62.07f, 62.07f, 0f, false, false, -62f, 62f)
                    curveTo(16f, 172f, 119.79f, 228.66f, 124.21f, 231f)
                    arcToRelative(8f, 8f, 0f, false, false, 7.58f, 0f)
                    curveTo(136.21f, 228.66f, 240f, 172f, 240f, 102f)
                    arcTo(62.07f, 62.07f, 0f, false, false, 178f, 40f)
                    close()
                    moveTo(128f, 214.8f)
                    curveTo(109.74f, 204.16f, 32f, 155.69f, 32f, 102f)
                    arcTo(46.06f, 46.06f, 0f, false, true, 78f, 56f)
                    curveTo(97.45f, 56f, 113.78f, 66.36f, 120.6f, 83f)
                    arcToRelative(8f, 8f, 0f, false, false, 14.8f, 0f)
                    curveTo(142.22f, 66.33f, 158.55f, 56f, 178f, 56f)
                    arcToRelative(46.06f, 46.06f, 0f, false, true, 46f, 46f)
                    curveTo(224f, 155.61f, 146.24f, 204.15f, 128f, 214.8f)
                    close()
                }
            }.build()
            return _heart!!
        }

    val ChatCircle: ImageVector
        get() {
            if (_chatCircle != null) return _chatCircle!!
            _chatCircle = ImageVector.Builder(
                name = "PhosphorRegular.ChatCircle",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(128f, 24f)
                    arcTo(104f, 104f, 0f, false, false, 36.18f, 176.88f)
                    lineTo(24.83f, 210.93f)
                    arcToRelative(16f, 16f, 0f, false, false, 20.24f, 20.24f)
                    lineTo(79.12f, 219.82f)
                    arcTo(104f, 104f, 0f, true, false, 128f, 24f)
                    close()
                    moveTo(128f, 216f)
                    arcToRelative(87.87f, 87.87f, 0f, false, true, -44.06f, -11.81f)
                    arcToRelative(8f, 8f, 0f, false, false, -6.54f, -0.67f)
                    lineTo(40f, 216f)
                    lineTo(52.47f, 178.6f)
                    arcToRelative(8f, 8f, 0f, false, false, -0.66f, -6.54f)
                    arcTo(88f, 88f, 0f, true, true, 128f, 216f)
                    close()
                }
            }.build()
            return _chatCircle!!
        }

    val ShareNetwork: ImageVector
        get() {
            if (_shareNetwork != null) return _shareNetwork!!
            _shareNetwork = ImageVector.Builder(
                name = "PhosphorRegular.ShareNetwork",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(176f, 160f)
                    arcToRelative(39.89f, 39.89f, 0f, false, false, -28.62f, 12.09f)
                    lineTo(101.28f, 142.46f)
                    arcToRelative(39.8f, 39.8f, 0f, false, false, 0f, -28.92f)
                    lineTo(147.38f, 83.91f)
                    arcToRelative(40f, 40f, 0f, true, false, -8.66f, -13.45f)
                    lineTo(92.62f, 100.09f)
                    arcToRelative(40f, 40f, 0f, true, false, 0f, 55.82f)
                    lineTo(138.72f, 185.54f)
                    arcTo(40f, 40f, 0f, true, false, 176f, 160f)
                    close()
                    moveTo(176f, 32f)
                    arcToRelative(24f, 24f, 0f, true, true, -24f, 24f)
                    arcTo(24f, 24f, 0f, false, true, 176f, 32f)
                    close()
                    moveTo(64f, 152f)
                    arcToRelative(24f, 24f, 0f, true, true, 24f, -24f)
                    arcTo(24f, 24f, 0f, false, true, 64f, 152f)
                    close()
                    moveTo(176f, 224f)
                    arcToRelative(24f, 24f, 0f, true, true, 24f, -24f)
                    arcTo(24f, 24f, 0f, false, true, 176f, 224f)
                    close()
                }
            }.build()
            return _shareNetwork!!
        }

    val ArrowLeft: ImageVector
        get() {
            if (_arrowLeft != null) return _arrowLeft!!
            _arrowLeft = ImageVector.Builder(
                name = "PhosphorRegular.ArrowLeft",
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = 256f,
                viewportHeight = 256f,
            ).apply {
                path(
                    fill = SolidColor(Color.Black),
                    stroke = null,
                    strokeLineWidth = 0f,
                    strokeLineCap = StrokeCap.Butt,
                    strokeLineJoin = StrokeJoin.Miter,
                    strokeLineMiter = 4f,
                    pathFillType = PathFillType.NonZero,
                ) {
                    moveTo(224f, 128f)
                    arcToRelative(8f, 8f, 0f, false, true, -8f, 8f)
                    horizontalLineTo(59.31f)
                    lineTo(117.66f, 194.34f)
                    arcToRelative(8f, 8f, 0f, false, true, -11.32f, 11.32f)
                    lineTo(34.34f, 133.66f)
                    arcToRelative(8f, 8f, 0f, false, true, 0f, -11.32f)
                    lineTo(106.34f, 50.34f)
                    arcToRelative(8f, 8f, 0f, false, true, 11.32f, 11.32f)
                    lineTo(59.31f, 120f)
                    horizontalLineTo(216f)
                    arcTo(8f, 8f, 0f, false, true, 224f, 128f)
                    close()
                }
            }.build()
            return _arrowLeft!!
        }
}

private var _bell: ImageVector? = null
private var _chatsCircle: ImageVector? = null
private var _arrowsClockwise: ImageVector? = null
private var _target: ImageVector? = null
private var _clock: ImageVector? = null
private var _user: ImageVector? = null
private var _rss: ImageVector? = null
private var _trophy: ImageVector? = null
private var _usersThree: ImageVector? = null
private var _bookmarkSimple: ImageVector? = null
private var _chartBar: ImageVector? = null
private var _list: ImageVector? = null
private var _sealCheck: ImageVector? = null
private var _play: ImageVector? = null
private var _caretRight: ImageVector? = null
private var _heart: ImageVector? = null
private var _chatCircle: ImageVector? = null
private var _shareNetwork: ImageVector? = null
private var _arrowLeft: ImageVector? = null
