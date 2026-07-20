package app.awrad.awrad_dhikrgoalstracker.ui.screens.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.MarkEmailRead
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.repository.VerificationOrigin
import kotlinx.coroutines.delay
import kotlin.math.ceil

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VerificationScreen(
    token: String?,
    onNavigateBack: () -> Unit,
    onVerified: () -> Unit,
    onSignIn: (String?, VerificationOrigin) -> Unit,
    viewModel: AuthViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val context by viewModel.pendingVerificationContext.collectAsState()
    val resendAt by viewModel.verificationResendAvailableAt.collectAsState()
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }

    LaunchedEffect(token) {
        token?.trim()?.takeIf { it.isNotEmpty() }?.let {
            viewModel.verifyEmail(it, onVerified)
        }
    }
    LaunchedEffect(resendAt) {
        while ((resendAt ?: 0L) > System.currentTimeMillis()) {
            now = System.currentTimeMillis()
            delay(1_000)
        }
        now = System.currentTimeMillis()
    }

    val cooldownSeconds = ceil(((resendAt ?: 0L) - now).coerceAtLeast(0L) / 1_000.0).toInt()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.auth_verify_navigation_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.action_back))
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 24.dp)
                .imePadding()
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                Icons.Rounded.MarkEmailRead,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.height(20.dp))
            Text(
                stringResource(R.string.auth_verify_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                stringResource(R.string.auth_verify_body, context?.email.orEmpty()),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            if (uiState.isVerifying) {
                Spacer(Modifier.height(24.dp))
                CircularProgressIndicator()
                Spacer(Modifier.height(12.dp))
                Text(stringResource(R.string.auth_verifying))
            }
            uiState.error?.let { error ->
                Spacer(Modifier.height(16.dp))
                Text(error, color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center)
            }
            if (uiState.verificationEmailSent) {
                Spacer(Modifier.height(16.dp))
                Text(
                    stringResource(R.string.auth_verification_sent),
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(Modifier.height(28.dp))
            Button(
                onClick = viewModel::resendVerification,
                enabled = !uiState.isResending && cooldownSeconds == 0,
                modifier = Modifier.fillMaxWidth().height(56.dp),
            ) {
                if (uiState.isResending) {
                    CircularProgressIndicator(
                        modifier = Modifier.height(20.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                } else {
                    Text(
                        if (cooldownSeconds > 0) {
                            stringResource(R.string.auth_resend_in, cooldownSeconds)
                        } else {
                            stringResource(R.string.auth_resend_verification)
                        },
                    )
                }
            }
            TextButton(onClick = {
                onSignIn(context?.email, context?.origin ?: VerificationOrigin.Account)
            }) {
                Text(stringResource(R.string.auth_sign_in_instead))
            }
            TextButton(onClick = onNavigateBack) {
                Text(stringResource(R.string.auth_continue_as_guest))
            }
        }
    }
}
