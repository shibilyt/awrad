package app.awrad.core.testing

import app.awrad.core.domain.dhikr.DhikrCatalog
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner

/** The shared catalog, `contracts/dhikr-catalog/v1/catalog.json`, parsed once: the catalog the app bundles. */
public val contractCatalog: DhikrCatalog by lazy {
    DhikrCatalog.parse(FixtureRunner.contractFile(FixtureModel.DHIKR_CATALOG, "catalog.json"))
}

/** Serves [catalog] (the shared one by default) and counts the loads. */
public class FakeDhikrCatalogSource(private val catalog: DhikrCatalog = contractCatalog) : DhikrCatalogSource {
    public var loads: Int = 0
        private set

    override suspend fun catalog(): DhikrCatalog {
        loads++
        return catalog
    }
}
