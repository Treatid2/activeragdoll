#include "staged_intrusive_output.h"

#include <cassert>
#include <utility>

void TestBoneNodeRebinding();

struct Object {
    int references{};
};

struct Owner {
    Object *ptr{};

    Owner() = default;
    Owner(const Owner &) = delete;
    Owner &operator=(const Owner &) = delete;

    Owner(Owner &&other) noexcept : ptr(std::exchange(other.ptr, nullptr)) {}

    Owner &operator=(Owner &&other) noexcept
    {
        if (this != &other) {
            Reset();
            ptr = std::exchange(other.ptr, nullptr);
        }
        return *this;
    }

    ~Owner() { Reset(); }

    void Reset()
    {
        if (ptr) {
            --ptr->references;
            ptr = nullptr;
        }
    }
};

Owner Retain(Object &object)
{
    ++object.references;
    Owner owner;
    owner.ptr = &object;
    return owner;
}

int main()
{
    TestBoneNodeRebinding();

    Object first;
    Object second;
    Owner output = Retain(first);

    const bool sameResult = QueryStagedIntrusiveOutput(output, [&](Owner &next) {
        assert(output.ptr == &first);
        assert(first.references == 1);
        next = Retain(first);
        assert(first.references == 2);
        return true;
    });
    assert(sameResult);
    assert(output.ptr == &first);
    assert(first.references == 1);

    const bool replacementResult = QueryStagedIntrusiveOutput(output, [&](Owner &next) {
        assert(output.ptr == &first);
        assert(first.references == 1);
        next = Retain(second);
        assert(second.references == 1);
        return true;
    });
    assert(replacementResult);
    assert(output.ptr == &second);
    assert(first.references == 0);
    assert(second.references == 1);

    const bool failureResult = QueryStagedIntrusiveOutput(output, [&](Owner &) {
        assert(output.ptr == &second);
        assert(second.references == 1);
        return false;
    });
    assert(!failureResult);
    assert(output.ptr == nullptr);
    assert(second.references == 0);
}
