#pragma once

#include <utility>

// Query engine-owned output into empty storage before replacing a retained
// owner. This prevents a release-before-acquire gap when callers reuse one
// local for consecutive queries.
template <class Owner, class Query>
bool QueryStagedIntrusiveOutput(Owner &out, Query &&query)
{
    Owner next;
    const bool result = std::forward<Query>(query)(next);
    if (result && out.ptr == next.ptr) {
        next.Reset();
    }
    else {
        out = std::move(next);
    }
    return result;
}
