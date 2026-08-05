package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.toStringResId
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelect
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelectOption
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CreateDhikrScreen(
    onNavigateBack: () -> Unit,
    onDhikrCreated: () -> Unit,
    viewModel: CreateDhikrViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val availableTags by viewModel.availableTags.collectAsStateWithLifecycle()
    var showTagSelector by rememberSaveable { mutableStateOf(false) }
    var tagSearchQuery by rememberSaveable { mutableStateOf("") }
    var newTagName by rememberSaveable { mutableStateOf("") }
    val pickAudio = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) viewModel.importAudio(uri)
    }

    LaunchedEffect(uiState.isSaved, uiState.isDeleted) {
        if (uiState.isSaved || uiState.isDeleted) onDhikrCreated()
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(
                            if (uiState.isEditing) R.string.edit_dhikr_title else R.string.create_dhikr_title,
                        ),
                    )
                },
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

            ComposerSelect(
                options = DhikrCategory.entries.map { category ->
                    ComposerSelectOption(
                        value = category,
                        label = stringResource(category.toStringResId()),
                    )
                },
                selected = uiState.category,
                sheetTitle = stringResource(R.string.create_dhikr_category_label),
                onSelect = viewModel::onCategoryChanged,
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedButton(
                onClick = {
                    tagSearchQuery = ""
                    showTagSelector = true
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = stringResource(R.string.create_dhikr_tags_label),
                        style = MaterialTheme.typography.labelMedium,
                    )
                    Text(
                        text = if (uiState.selectedTagIds.isEmpty()) {
                            stringResource(R.string.create_dhikr_tags_none)
                        } else {
                            stringResource(R.string.create_dhikr_tags_selected, uiState.selectedTagIds.size)
                        },
                    )
                }
            }

            OutlinedButton(
                onClick = {
                    pickAudio.launch(
                        arrayOf(
                            "audio/mpeg",
                            "audio/mp4",
                            "audio/aac",
                            "audio/wav",
                            "audio/x-wav",
                            "audio/*",
                        ),
                    )
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = stringResource(
                        if (uiState.ownedAudioName != null) R.string.replace_audio else R.string.import_audio,
                    ),
                )
            }
            if (uiState.ownedAudioMissing) {
                Text(
                    text = stringResource(R.string.audio_missing_body),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            } else if (uiState.ownedAudioName != null) {
                OutlinedButton(onClick = viewModel::removeAudio, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.remove_audio))
                }
            }

            val canEditAudioCount = CreateDhikrEditorState.canEditAudioCount(
                hasStagedAudio = uiState.stagedAudio != null,
                hasPersistedOwnedAudio =
                    uiState.persistedOwnedAudioPresent && !uiState.removeOwnedAudioPending,
            )
            Text(
                text = stringResource(R.string.create_dhikr_counts_per_play),
                style = MaterialTheme.typography.titleSmall,
                color = if (canEditAudioCount) {
                    MaterialTheme.colorScheme.onSurfaceVariant
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                },
            )
            val countsCd = stringResource(R.string.cd_counts_per_play)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.semantics { contentDescription = countsCd },
            ) {
                IconButton(
                    enabled = canEditAudioCount,
                    onClick = {
                        viewModel.onAudioCountPerPlayChanged(uiState.audioCountPerPlay - 1)
                    },
                ) {
                    Icon(
                        Icons.Filled.Remove,
                        contentDescription = stringResource(R.string.cd_decrease_counts_per_play),
                    )
                }
                Text(
                    text = uiState.audioCountPerPlay.toString(),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.width(40.dp),
                    textAlign = TextAlign.Center,
                    color = if (canEditAudioCount) {
                        MaterialTheme.colorScheme.onSurface
                    } else {
                        MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    },
                )
                IconButton(
                    enabled = canEditAudioCount,
                    onClick = {
                        viewModel.onAudioCountPerPlayChanged(uiState.audioCountPerPlay + 1)
                    },
                ) {
                    Icon(
                        Icons.Filled.Add,
                        contentDescription = stringResource(R.string.cd_increase_counts_per_play),
                    )
                }
            }
            if (!canEditAudioCount) {
                Text(
                    text = stringResource(R.string.create_dhikr_counts_requires_audio),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            uiState.audioError?.let { reason ->
                val message = when (reason) {
                    "SIZE" -> stringResource(R.string.custom_audio_too_large)
                    "DURATION" -> stringResource(R.string.custom_audio_too_long)
                    "CORRUPT" -> stringResource(R.string.custom_audio_corrupt)
                    "IO" -> stringResource(R.string.custom_audio_io)
                    else -> stringResource(R.string.custom_audio_unsupported)
                }
                Text(text = message, color = MaterialTheme.colorScheme.error)
            }
            uiState.saveError?.let { code ->
                val message = when (code) {
                    "partial_failure" -> stringResource(R.string.create_dhikr_partial_failure)
                    "too_many_tags" -> stringResource(R.string.tag_limit_reached)
                    else -> stringResource(R.string.create_dhikr_save_failed)
                }
                Text(text = message, color = MaterialTheme.colorScheme.error)
            }

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

            if (uiState.isEditing) {
                OutlinedButton(
                    onClick = viewModel::delete,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(stringResource(R.string.delete_dhikr))
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    if (showTagSelector) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        val normalizedQuery = tagSearchQuery.trim()
        val matchingTags = availableTags.filter { tag ->
            normalizedQuery.isBlank() || tag.name.contains(normalizedQuery, ignoreCase = true)
        }
        ModalBottomSheet(
            onDismissRequest = { showTagSelector = false },
            sheetState = sheetState,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp, vertical = 12.dp)
                    .padding(bottom = 28.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = stringResource(R.string.create_dhikr_tags_label),
                    style = MaterialTheme.typography.titleLarge,
                )
                OutlinedTextField(
                    value = tagSearchQuery,
                    onValueChange = { tagSearchQuery = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.create_dhikr_tags_search)) },
                    singleLine = true,
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    OutlinedTextField(
                        value = newTagName,
                        onValueChange = { newTagName = it },
                        modifier = Modifier.weight(1f),
                        label = { Text(stringResource(R.string.tag_name_label)) },
                        singleLine = true,
                    )
                    OutlinedButton(
                        onClick = {
                            if (newTagName.isNotBlank()) {
                                viewModel.createAndSelectTag(newTagName)
                                newTagName = ""
                            }
                        },
                    ) {
                        Text(stringResource(R.string.create_tag))
                    }
                }
                if (matchingTags.isEmpty()) {
                    Text(
                        text = if (availableTags.isEmpty()) {
                            stringResource(R.string.create_dhikr_tags_empty)
                        } else {
                            stringResource(R.string.create_dhikr_tags_no_match)
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        matchingTags.forEach { tag ->
                            val selected = tag.id in uiState.selectedTagIds
                            Surface(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { viewModel.toggleTag(tag.id) },
                                shape = RoundedCornerShape(16.dp),
                                color = if (selected) {
                                    MaterialTheme.colorScheme.primaryContainer.copy(
                                        alpha = if (isAwradDarkTheme()) 0.5f else 0.7f,
                                    )
                                } else {
                                    Color.Transparent
                                },
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = tag.name,
                                        style = MaterialTheme.typography.bodyLarge,
                                        fontWeight = if (selected) {
                                            androidx.compose.ui.text.font.FontWeight.SemiBold
                                        } else {
                                            androidx.compose.ui.text.font.FontWeight.Normal
                                        },
                                        modifier = Modifier.weight(1f),
                                    )
                                    if (selected) {
                                        Surface(
                                            modifier = Modifier.size(24.dp),
                                            shape = androidx.compose.foundation.shape.CircleShape,
                                            color = MaterialTheme.colorScheme.primary,
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Check,
                                                contentDescription = null,
                                                tint = MaterialTheme.colorScheme.onPrimary,
                                                modifier = Modifier.padding(4.dp),
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
