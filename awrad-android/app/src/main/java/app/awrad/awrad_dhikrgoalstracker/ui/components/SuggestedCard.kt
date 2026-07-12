package app.awrad.awrad_dhikrgoalstracker.ui.components

import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R

@Composable
fun SuggestedCard(
    arabic: String,
    transliteration: String,
    translation: String,
    progress: Float,
    progressText: String,
    onStartCounting: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primary,
        ),
        shape = MaterialTheme.shapes.large,
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
        ) {
            Text(
                text = stringResource(R.string.suggested_card_title),
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.8f),
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = arabic,
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontFamily = NotoNaskhArabicFontFamily,
                    fontSize = 28.sp,
                    lineHeight = 40.sp,
                ),
                color = Color.White,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = transliteration,
                style = MaterialTheme.typography.titleSmall,
                color = Color.White.copy(alpha = 0.9f),
                fontWeight = FontWeight.Medium,
            )

            Text(
                text = translation,
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.7f),
            )

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .clip(MaterialTheme.shapes.extraSmall),
                        color = Color.White,
                        trackColor = Color.White.copy(alpha = 0.3f),
                    )
                    Text(
                        text = progressText,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }

                Button(
                    onClick = onStartCounting,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = MaterialTheme.colorScheme.primary,
                    ),
                    shape = MaterialTheme.shapes.medium,
                    modifier = Modifier.padding(start = 16.dp),
                ) {
                    Text(
                        text = stringResource(R.string.action_start_counting),
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}
