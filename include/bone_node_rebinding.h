#pragma once

#include <cstddef>
#include <string_view>

inline bool ShouldRebindConvertedWeaponNode(
    std::string_view nodeName, bool enableRebinding, bool includeUnobservedNodes)
{
    if (!enableRebinding) return false;
    return nodeName == "SHIELD" || includeUnobservedNodes;
}

template <class Entry>
bool IsBoneNodeEntryRangeValid(const Entry* entries, std::size_t count)
{
    constexpr std::size_t maxReasonableBoneCount = 4096;
    return count <= maxReasonableBoneCount && (count == 0 || entries != nullptr);
}

// The caller owns the graph update lock and retains both node lifetimes.
template <class Entry, class OldNode, class NewNode>
std::size_t RebindBoneNodeEntries(Entry* entries, std::size_t count, OldNode* oldNode, NewNode* newNode)
{
    if (!oldNode || !newNode) return 0;

    std::size_t rebound = 0;
    for (std::size_t i = 0; i < count; ++i) {
        if (entries[i].node == oldNode) {
            entries[i].node = newNode;
            ++rebound;
        }
    }
    return rebound;
}
