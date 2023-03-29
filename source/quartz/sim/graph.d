module quartz.sim.graph;

import quartz.error : QuartzError;

// A directed acyclic schedule. Feedback inside a phase-locked loop stays
// inside one node, so the graph of an experiment can be ordered once and
// hashed. A back edge is rejected instead of being run in an arbitrary order.

@safe:

struct Dag {
    string[] nodes;
    int[] from;
    int[] to;

    int add(string name) {
        nodes ~= name;
        return cast(int) nodes.length - 1;
    }

    void link(int src, int dst) {
        from ~= src;
        to ~= dst;
    }

    bool hasCycle() const {
        int[] color = new int[](nodes.length);
        bool cyclic = false;
        bool walk(int node) {
            if (color[node] == 1) {
                return true;
            }
            if (color[node] == 2) {
                return false;
            }
            color[node] = 1;
            foreach (e; 0 .. from.length) {
                if (from[e] == node && walk(to[e])) {
                    return true;
                }
            }
            color[node] = 2;
            return false;
        }
        foreach (n; 0 .. nodes.length) {
            if (walk(cast(int) n)) {
                cyclic = true;
            }
        }
        return cyclic;
    }

    int[] order() const {
        if (hasCycle()) {
            throw new QuartzError("experiment graph has a cycle");
        }
        int[] indeg = new int[](nodes.length);
        foreach (dst; to) {
            indeg[dst]++;
        }
        int[] ready;
        foreach (i, d; indeg) {
            if (d == 0) {
                ready ~= cast(int) i;
            }
        }
        int[] seq;
        while (ready.length) {
            int n = ready[0];
            ready = ready[1 .. $].dup;
            seq ~= n;
            foreach (e; 0 .. from.length) {
                if (from[e] == n) {
                    indeg[to[e]]--;
                    if (indeg[to[e]] == 0) {
                        ready ~= to[e];
                    }
                }
            }
        }
        return seq;
    }
}

unittest {
    auto dag = Dag();
    int bits = dag.add("bits");
    int map = dag.add("map");
    int channel = dag.add("channel");
    int demap = dag.add("demap");
    dag.link(bits, map);
    dag.link(map, channel);
    dag.link(channel, demap);
    assert(!dag.hasCycle());
    auto seq = dag.order();
    assert(seq == [bits, map, channel, demap]);
    dag.link(demap, map);
    assert(dag.hasCycle());
}
