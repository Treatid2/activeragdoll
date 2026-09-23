#include "bone_node_rebinding.h"

#include <cassert>
#include <cstdint>

struct Object {};
struct Node : Object {};
struct FadeNode : Node {};
struct Entry {
    Node* node;
    std::uint32_t flattenedBoneTreeOffset;
    std::uint32_t metadata;
};

void TestBoneNodeRebinding()
{
    assert(ShouldRebindConvertedWeaponNode("SHIELD", true, false));
    assert(!ShouldRebindConvertedWeaponNode("WEAPON", true, false));
    assert(ShouldRebindConvertedWeaponNode("WEAPON", true, true));
    assert(!ShouldRebindConvertedWeaponNode("SHIELD", false, true));

    Node oldNode, replacement, unrelated;
    Entry first[] = {{&oldNode, 0xFFFFFFFF, 11}, {&unrelated, 7, 12},
        {&oldNode, 13, 14}, {nullptr, 15, 16}};
    Entry second[] = {{&oldNode, 17, 18}};
    assert(RebindBoneNodeEntries(first, 4, &oldNode, &replacement) == 2);
    assert(RebindBoneNodeEntries(second, 1, &oldNode, &replacement) == 1);
    assert(first[0].node == &replacement && first[2].node == &replacement);
    assert(first[1].node == &unrelated && first[3].node == nullptr);
    assert(first[0].flattenedBoneTreeOffset == 0xFFFFFFFF && first[0].metadata == 11);
    assert(first[2].flattenedBoneTreeOffset == 13 && first[2].metadata == 14);
    assert(second[0].flattenedBoneTreeOffset == 17 && second[0].metadata == 18);
    assert(RebindBoneNodeEntries(first, 4, &oldNode, &replacement) == 0);
    assert(RebindBoneNodeEntries(first, 0, &replacement, &oldNode) == 0);
    assert(RebindBoneNodeEntries(first, 4, static_cast<Node*>(nullptr), &oldNode) == 0);
    assert(RebindBoneNodeEntries(first, 4, &replacement, static_cast<Node*>(nullptr)) == 0);
    FadeNode fadeNode;
    Object* oldBase = &replacement;
    assert(RebindBoneNodeEntries(first, 4, oldBase, &fadeNode) == 2);
    assert(first[0].node == &fadeNode && first[2].node == &fadeNode);
    assert(first[0].flattenedBoneTreeOffset == 0xFFFFFFFF && first[0].metadata == 11);
    assert(IsBoneNodeEntryRangeValid(first, 4));
    assert(IsBoneNodeEntryRangeValid(static_cast<Entry*>(nullptr), 0));
    assert(!IsBoneNodeEntryRangeValid(static_cast<Entry*>(nullptr), 1));
    assert(!IsBoneNodeEntryRangeValid(first, 4097));
}
