"""
s1_graph_parsing.py
Stage 1: Parse the self-contained Cytoscape graph JSON into a NetworkX directed graph.

Input:  graph_creation/result/{Exposure}_to_{Outcome}_degreeN.json
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
    find_graph_json,
    get_s1_graph_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)


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

    # Use the self-contained Cytoscape graph JSON (pmid_data is embedded per edge)
    graph_file = find_graph_json(exposure, outcome, degree)

    if graph_file:
        print(f"Input file: {graph_file}")
        print("Input format: Cytoscape graph JSON")
        G = parse_graph_json(graph_file)
        input_format = "cytoscape_json"
        input_file = str(graph_file)
    else:
        raise FileNotFoundError(
            f"No graph JSON found for {exposure} -> {outcome} (degree {degree}). "
            f"Expected: graph_creation/result/{exposure}_to_{outcome}_degree{degree}.json"
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
