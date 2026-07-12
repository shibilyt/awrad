package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.toStringResId
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CreateDhikrScreen(
    onNavigateBack: () -> Unit,
    onDhikrCreated: () -> Unit,
    viewModel: CreateDhikrViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(uiState.isSaved) {
        if (uiState.isSaved) onDhikrCreated()
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.create_dhikr_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                },
            )
        },
    ) { padding ->
        val fieldColors = OutlinedTextFieldDefaults.colors(
            unfocusedContainerColor = if (isAwradDarkTheme()) MaterialTheme.colorScheme.surfaceContainerHigh else MaterialTheme.colorScheme.surface,
            focusedContainerColor = if (isAwradDarkTheme()) MaterialTheme.colorScheme.surfaceContainerHigh else MaterialTheme.colorScheme.surface,
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp)
                .imePadding()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Spacer(modifier = Modifier.height(4.dp))

            // Arabic text (required)
            OutlinedTextField(
                value = uiState.arabic,
                onValueChange = viewModel::onArabicChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.create_dhikr_arabic_label)) },
                placeholder = { Text(stringResource(R.string.create_dhikr_arabic_hint)) },
                shape = RoundedCornerShape(18.dp),
                colors = fieldColors,
                minLines = 2,
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    fontFamily = NotoNaskhArabicFontFamily,
                    textAlign = TextAlign.End,
                ),
            )

            // Title
            OutlinedTextField(
                value = uiState.title,
                onValueChange = viewModel::onTitleChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.create_dhikr_title_label)) },
                placeholder = { Text(stringResource(R.string.create_dhikr_title_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
                colors = fieldColors,
            )

            // Transliteration
            OutlinedTextField(
                value = uiState.transliteration,
                onValueChange = viewModel::onTransliterationChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.create_dhikr_transliteration_label)) },
                placeholder = { Text(stringResource(R.string.create_dhikr_transliteration_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
                colors = fieldColors,
            )

            // Translation
            OutlinedTextField(
                value = uiState.translation,
                onValueChange = viewModel::onTranslationChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.create_dhikr_translation_label)) },
                placeholder = { Text(stringResource(R.string.create_dhikr_translation_hint)) },
                shape = RoundedCornerShape(18.dp),
                colors = fieldColors,
                minLines = 2,
            )

            // Category
            Text(
                text = stringResource(R.string.create_dhikr_category_label),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                DhikrCategory.entries.forEach { category ->
                    FilterChip(
                        selected = uiState.category == category,
                        onClick = { viewModel.onCategoryChanged(category) },
                        label = { Text(stringResource(category.toStringResId())) },
                        colors = FilterChipDefaults.filterChipColors(
                            containerColor = if (isAwradDarkTheme()) MaterialTheme.colorScheme.surfaceContainerHigh else MaterialTheme.colorScheme.surface,
                            labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                        ),
                        border = FilterChipDefaults.filterChipBorder(
                            enabled = true,
                            selected = uiState.category == category,
                            borderColor = Color.Transparent,
                            selectedBorderColor = Color.Transparent,
                        ),
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Button(
                onClick = viewModel::save,
                modifier = Modifier.fillMaxWidth().height(56.dp),
                enabled = uiState.arabic.isNotBlank() && !uiState.isSaving,
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(
                    text = if (uiState.isSaving) stringResource(R.string.create_dhikr_saving)
                    else stringResource(R.string.create_dhikr_save),
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
