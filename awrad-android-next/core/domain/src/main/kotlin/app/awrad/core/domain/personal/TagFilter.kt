package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId

/**
 * The Library's tag filter: with tags [selected], a dhikr shows only when it carries every one of them (AND).
 * Nothing selected shows everything.
 */
public object TagFilter {
    public fun <T> filter(
        items: List<T>,
        selected: Set<AwradId>,
        tagsByDhikr: Map<AwradId, List<AwradId>>,
        idOf: (T) -> AwradId,
    ): List<T> = if (selected.isEmpty()) {
        items
    } else {
        items.filter { item -> tagsByDhikr[idOf(item)].orEmpty().containsAll(selected) }
    }
}
