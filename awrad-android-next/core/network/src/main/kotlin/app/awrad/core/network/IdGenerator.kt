package app.awrad.core.network

/**
 * Makes the IDs this module sends: the installation id and every `Idempotency-Key`. Each is a UUIDv7
 * (ADR-2026-10-28). `:core:data` binds it to the domain's `UuidV7`, since this module can't see `:core:domain`.
 */
public fun interface IdGenerator {
    public fun newId(): String
}
