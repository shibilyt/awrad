import AwradDomain
import SwiftUI

extension LibraryScreen {
    /// The screen a pushed destination shows. A dhikr, or a custom one being edited, that isn't (or is
    /// no longer) there shows nothing.
    @ViewBuilder func destination(_ destination: LibraryModel.Destination) -> some View {
        let personal = state.personal
        switch destination {
        case .collection(let key):
            if let collection = content.catalog.collection(key) {
                CollectionScreen(collection: collection, content: content) { send(.openDhikr(key: $0.key)) }
            }
        case .dhikr(let key):
            if let dhikr = content.dhikr(key, in: personal) {
                DhikrDetailRoute(
                    dhikr: dhikr, content: content, personal: personal, services: services, navigate: send)
            }
        case .yourDhikrs:
            YourDhikrsScreen(
                customDhikrs: personal.customDhikrs, content: content,
                onOpen: { send(.openDhikr(key: $0.key)) }, onCreate: { send(.openEditor(nil)) })
        case .editor(let id):
            if id == nil || id.flatMap(personal.customDhikr) != nil {
                CustomDhikrEditorRoute(
                    existing: id.flatMap(personal.customDhikr), personal: personal, services: services,
                    navigate: send)
            }
        case .manageTags(let dhikr):
            ManageTagsRoute(dhikr: dhikr, personal: personal, library: services.library)
        }
    }
}
