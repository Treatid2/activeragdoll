#pragma once

#include <cstddef>

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
