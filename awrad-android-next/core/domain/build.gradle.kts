plugins {
    id("awrad.jvm.library")
}

dependencies {
    api(libs.kotlinx.coroutines.core)
    api(libs.javax.inject)
    testImplementation(project(":core:testing"))
}
