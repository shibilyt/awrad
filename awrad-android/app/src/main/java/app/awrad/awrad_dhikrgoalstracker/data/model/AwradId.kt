package app.awrad.awrad_dhikrgoalstracker.data.model

import java.util.UUID

/** Canonical identity used by every cross-platform progress entity. */
typealias AwradId = UUID

fun newAwradId(): AwradId = UUID.randomUUID()
