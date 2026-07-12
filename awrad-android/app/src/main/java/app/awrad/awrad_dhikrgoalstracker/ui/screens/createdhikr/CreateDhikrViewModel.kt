package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CreateDhikrUiState(
    val title: String = "",
    val arabic: String = "",
    val transliteration: String = "",
    val translation: String = "",
    val category: DhikrCategory = DhikrCategory.GENERAL,
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
)

@HiltViewModel
class CreateDhikrViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(CreateDhikrUiState())
    val uiState: StateFlow<CreateDhikrUiState> = _uiState.asStateFlow()

    val isValid: Boolean
        get() = _uiState.value.arabic.isNotBlank()

    fun onTitleChanged(value: String) {
        _uiState.update { it.copy(title = value) }
    }

    fun onArabicChanged(value: String) {
        _uiState.update { it.copy(arabic = value) }
    }

    fun onTransliterationChanged(value: String) {
        _uiState.update { it.copy(transliteration = value) }
    }

    fun onTranslationChanged(value: String) {
        _uiState.update { it.copy(translation = value) }
    }

    fun onCategoryChanged(category: DhikrCategory) {
        _uiState.update { it.copy(category = category) }
    }

    fun save() {
        val state = _uiState.value
        if (state.arabic.isBlank() || state.isSaving) return

        _uiState.update { it.copy(isSaving = true) }
        viewModelScope.launch {
            val dhikr = Dhikr(
                title = state.title.ifBlank { state.transliteration.ifBlank { state.arabic.take(30) } },
                arabic = state.arabic,
                transliteration = state.transliteration,
                translation = state.translation,
                audioUrl = null,
                audioFileName = null,
                category = state.category,
            )
            dhikrRepository.createDhikr(dhikr)
            _uiState.update { it.copy(isSaving = false, isSaved = true) }
        }
    }
}
