"""
s1_graph_parsing.py
Stage 1: Parse causal assertions JSON into a NetworkX directed graph.

Input:  graph_creation/result/{Exposure}_to_{Outcome}_degreeN_causal_assertions.json
Output: data/{Exposure}_{Outcome}/s1_graph/
          - graph.graphml   (NetworkX graph serialized)
          - metadata.csv    (exposure, outcome, node/edge counts)
          - edges.csv       (full edge list with predicates and evidence counts)
"""

import json
import csv
from pathlib import Path

import networkx as nx

from .config import GRAPH_CONFIG
from .utils import (
    find_assertions_json,
    find_graph_json,
    get_s1_graph_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)


def parse_assertions_json(filepath: Path) -> nx.DiGraph:
    """Build a NetworkX DiGraph from a causal_assertions JSON file."""
    with open(filepath) as f:
        data = json.load(f)

    assertions = data.get("assertions", [])
    if not assertions:
        raise ValueError(f"No assertions found in {filepath}")

    G = nx.DiGraph()

    for a in assertions:
        subj = a["subj"]
        obj = a["obj"]
        predicate = a.get("predicate", "CAUSES")
        ev_count = a.get("ev_count", 0)
        subj_cui = a.get("subj_cui", "")
        obj_cui = a.get("obj_cui", "")

        # Add nodes with CUI metadata
        if subj not in G:
            G.add_node(subj, cui=subj_cui, node_type="regular")
        if obj not in G:
            G.add_node(obj, cui=obj_cui, node_type="regular")

        # Add or update edge (keep highest evidence count if duplicate)
        if G.has_edge(subj, obj):
            existing = G[subj][obj].get("ev_count", 0)
            if ev_count > existing:
                G[subj][obj]["ev_count"] = ev_count
                G[subj][obj]["predicate"] = predicate
        else:
            G.add_edge(subj, obj, predicate=predicate, ev_count=ev_count)

    return G


def parse_graph_json(filepath: Path) -> nx.DiGraph:
    """Build a NetworkX DiGraph from a Cytoscape-style graph JSON file."""
    with open(filepath) as f:
        data = json.load(f)

    elements = data.get("elements", {})
    nodes = elements.get("nodes", [])
    edges = elements.get("edges", [])

    G = nx.DiGraph()

    for node in nodes:
        d = node.get("data", {})
        node_id = d.get("id", "")
        label = d.get("label", node_id)
        node_type = d.get("node_type", d.get("type", "regular"))
        if node_type in ("default", ""):
            node_type = "regular"
        G.add_node(node_id, label=label, node_type=node_type)

    for edge in edges:
        d = edge.get("data", {})
        src = d.get("source", "")
        tgt = d.get("target", "")
        predicate = d.get("predicate", "CAUSES")
        ev_count = d.get("evidence_count", 0)
        subj_cui = d.get("subject_cui", "")
        obj_cui = d.get("object_cui", "")
        if src and tgt:
            G.add_edge(src, tgt, predicate=predicate, ev_count=ev_count)
            # Update CUI info on nodes if available
            if subj_cui and not G.nodes[src].get("cui"):
                G.nodes[src]["cui"] = subj_cui
            if obj_cui and not G.nodes[tgt].get("cui"):
                G.nodes[tgt]["cui"] = obj_cui

    return G


def apply_node_roles(G: nx.DiGraph, exposure: str, outcome: str) -> nx.DiGraph:
    """Mark exposure and outcome nodes in the graph."""
    if exposure in G:
        G.nodes[exposure]["node_type"] = "exposure"
    if outcome in G:
        G.nodes[outcome]["node_type"] = "outcome"
    return G


def run_stage1(exposure: str, outcome: str, degree: int = 2) -> nx.DiGraph:
    """Execute Stage 1: parse input and save graph artifacts."""
    print_header("Graph Parser (Stage 1)", exposure, outcome)

    output_dir = get_s1_graph_dir(exposure, outcome)
    ensure_dir(output_dir)

    # Prefer assertions JSON (richer metadata), fall back to graph JSON
    assertions_file = find_assertions_json(exposure, outcome, degree)
    graph_file = find_graph_json(exposure, outcome, degree)

    if assertions_file:
        print(f"Input file: {assertions_file}")
        print("Input format: causal_assertions JSON")
        G = parse_assertions_json(assertions_file)
        input_format = "causal_assertions"
        input_file = str(assertions_file)
    elif graph_file:
        print(f"Input file: {graph_file}")
        print("Input format: Cytoscape graph JSON")
        G = parse_graph_json(graph_file)
        input_format = "cytoscape_json"
        input_file = str(graph_file)
    else:
        raise FileNotFoundError(
            f"No input JSON found for {exposure} -> {outcome} (degree {degree})"
        )

    # Apply exposure/outcome roles
    G = apply_node_roles(G, exposure, outcome)

    print(f"Nodes: {G.number_of_nodes()}")
    print(f"Edges: {G.number_of_edges()}")

    # Save graph as GraphML
    graphml_path = output_dir / "graph.graphml"
    nx.write_graphml(G, str(graphml_path))
    print(f"Saved graph to: {graphml_path}")

    # Save edges CSV
    edges_path = output_dir / "edges.csv"
    with open(edges_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["source", "target", "predicate", "ev_count"])
        for u, v, d in G.edges(data=True):
            writer.writerow([u, v, d.get("predicate", ""), d.get("ev_count", 0)])
    print(f"Saved edges to: {edges_path}")

    # Save metadata CSV
    meta_path = output_dir / "metadata.csv"
    with open(meta_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["key", "value"])
        writer.writerow(["exposure", exposure])
        writer.writerow(["outcome", outcome])
        writer.writerow(["input_file", input_file])
        writer.writerow(["input_format", input_format])
        writer.writerow(["n_nodes", G.number_of_nodes()])
        writer.writerow(["n_edges", G.number_of_edges()])
    print(f"Saved metadata to: {meta_path}")

    print_complete("Graph Parser (Stage 1)")
    return G


if __name__ == "__main__":
    args = parse_args("Stage 1: Parse graph input")
    run_stage1(args.exposure, args.outcome, args.degree)
