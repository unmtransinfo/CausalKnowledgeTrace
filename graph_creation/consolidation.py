#!/usr/bin/env python3

import argparse
from langchain.llms import Ollama
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
import re
import json
import os
from typing import Dict, List, Optional, Any

class SemDAGProcessor:
    def __init__(self, args):
        """Initialize SemDAG processor with CLI arguments"""
        self.llm = Ollama(model=args.model)
        
        # Set up color scheme
        self.color_scheme = {
            "Primary": args.color_primary,
            "Biological_Process": args.color_biological,
            "Neural": args.color_neural,
            "Molecular": args.color_molecular,
            "Disease": args.color_disease,
            "Other": args.color_other
        }
        
        # Set up visualization config
        self.visualization_config = {
            "width": args.viz_width,
            "height": args.viz_height,
            "physics": {
                "solver": "forceAtlas2Based",
                "gravitationalConstant": args.gravitational_constant,
                "centralGravity": 0.02,
                "springLength": args.spring_length,
                "springConstant": 0.08,
                "damping": 0.4,
                "avoidOverlap": 1
            },
            "nodes": {
                "font_size": args.font_size,
                "stroke_width": 2,
                "shadow": True
            },
            "edges": {
                "width": args.edge_width,
                "color": "#2F4F4F80",
                "smooth": True
            }
        }
        
        # Default consolidation rules
        self.consolidation_rules = {
            "cardiac": ["cardiac", "heart", "myocardial", "coronary"],
            "neuro": ["neurological", "brain", "neural", "cognitive"],
            "inflammation": ["inflammation", "inflammatory", "itis"],
            "vascular": ["vascular", "arterial", "venous"],
            "metabolic": ["metabolic", "diabetes", "insulin"],
            "death": ["death", "mortality", "fatal"],
            "injury": ["injury", "trauma", "damage"],
            "infection": ["infection", "infectious", "bacterial", "viral"],
            "generic_nodes": [
                "disease", "disorder", "syndrome", "pathology", "condition",
                "process", "pathway", "mechanism", "response", "effect",
                "assessment", "evaluation", "procedure", "therapy", "treatment"
            ]
        }
        
        # Set up prompt template
        self.node_consolidation_prompt = PromptTemplate(
            input_variables=["dag_content"],
            template="""
            Analyze this DAG content and:
            1. Identify synonymous nodes that should be consolidated
            2. List generic nodes that should be removed
            3. Return a JSON with two lists: 'consolidations' and 'removals'

            DAG Content:
            {dag_content}
            """
        )

    def extract_dag_definition(self, r_file_path: str) -> Optional[str]:
        """Extract DAG definition from R file"""
        with open(r_file_path, 'r') as file:
            content = file.read()
            match = re.search(r'dag\s*{(.*?)}', content, re.DOTALL)
            if match:
                return match.group(1).strip()
            return None

    def generate_r_visualization_code(self, dag_definition: str) -> str:
        """Generate R code for interactive visualization"""
        viz_config = self.visualization_config
        physics_config = viz_config["physics"]
        nodes_config = viz_config["nodes"]
        edges_config = viz_config["edges"]

        # Generate color assignments
        color_assignments = []
        for group, color in self.color_scheme.items():
            color_assignments.append(f'            {group} = "{color}"')
        color_scheme_r = ",\n".join(color_assignments)

        r_code = f"""
        library(dagitty)
        library(igraph)
        library(visNetwork)
        library(dplyr)

        g <- dagitty('dag {{
        {dag_definition}
        }}')

        # Create nodes dataframe
        nodes <- data.frame(
            id = V(dagitty2graph(g))$name,
            label = gsub("_", " ", V(dagitty2graph(g))$name),
            group = case_when(
                V(dagitty2graph(g))$name %in% c("Depression", "Alzheimers_Disease") ~ "Primary",
                V(dagitty2graph(g))$name %in% c("Inflammation", "Oxidative_Stress", "Cell_Death") ~ "Biological_Process",
                V(dagitty2graph(g))$name %in% c("Neurodegeneration", "Memory_Loss", "Cognitive_Decline") ~ "Neural",
                V(dagitty2graph(g))$name %in% c("Amyloid", "Tau", "MAPT", "APP") ~ "Molecular",
                V(dagitty2graph(g))$name %in% c("Cardiovascular_Disease", "Diabetes", "Stroke") ~ "Disease",
                TRUE ~ "Other"
            ),
            font.size = {nodes_config["font_size"]},
            font.color = "black",
            stringsAsFactors = FALSE
        )

        # Define color scheme
        color_scheme <- list(
{color_scheme_r}
        )

        nodes$color <- unlist(color_scheme[nodes$group])

        # Create edges dataframe
        edges <- data.frame(
            from = get.edgelist(dagitty2graph(g))[,1],
            to = get.edgelist(dagitty2graph(g))[,2],
            arrows = "to",
            smooth = {str(edges_config["smooth"]).lower()},
            width = {edges_config["width"]},
            color = "{edges_config["color"]}",
            stringsAsFactors = FALSE
        )

        # Create interactive visualization
        visNetwork(nodes, edges, width = "{viz_config["width"]}", height = "{viz_config["height"]}") %>%
            visPhysics(
                solver = "{physics_config["solver"]}",
                forceAtlas2Based = list(
                    gravitationalConstant = {physics_config["gravitationalConstant"]},
                    centralGravity = {physics_config["centralGravity"]},
                    springLength = {physics_config["springLength"]},
                    springConstant = {physics_config["springConstant"]},
                    damping = {physics_config["damping"]},
                    avoidOverlap = {physics_config["avoidOverlap"]}
                )
            ) %>%
            visOptions(
                highlightNearest = list(enabled = TRUE, degree = 1),
                nodesIdSelection = TRUE
            ) %>%
            visNodes(
                shadow = {str(nodes_config["shadow"]).upper()},
                font = list(size = {nodes_config["font_size"]}, strokeWidth = {nodes_config["stroke_width"]})
            ) %>%
            visEdges(
                smooth = list(enabled = TRUE, type = "curvedCW")
            )
        """
        return r_code

    def consolidate_nodes(self, dag_definition: str) -> str:
        """Use LangChain to identify and consolidate nodes"""
        chain = LLMChain(llm=self.llm, prompt=self.node_consolidation_prompt)
        response = chain.run(dag_content=dag_definition)

        try:
            recommendations = json.loads(response)
            return self.apply_consolidations(dag_definition, recommendations)
        except json.JSONDecodeError:
            print("Error parsing LLM response")
            return dag_definition

    def apply_consolidations(self, dag_definition: str, recommendations: Dict[str, Any]) -> str:
        """Apply the recommended consolidations and removals"""
        modified_dag = dag_definition

        # Apply consolidations
        for consolidation in recommendations.get('consolidations', []):
            for synonym in consolidation['synonyms']:
                modified_dag = modified_dag.replace(synonym, consolidation['main_term'])

        # Remove generic nodes
        for node in recommendations.get('removals', []):
            lines = modified_dag.split('\n')
            lines = [line for line in lines if node not in line]
            modified_dag = '\n'.join(lines)

        return modified_dag

    def process_semdag(self, args):
        """Main processing function"""
        if args.verbose:
            print("Processing SemDAG file...")

        # Extract DAG definition
        dag_definition = self.extract_dag_definition(args.input_file)
        if not dag_definition:
            print("Error: Could not extract DAG definition")
            return

        if args.consolidate:
            if args.verbose:
                print("Consolidating nodes...")
            consolidated_dag = self.consolidate_nodes(dag_definition)
        else:
            consolidated_dag = dag_definition

        if args.verbose:
            print("Generating visualization code...")
        
        # Generate R visualization code
        r_code = self.generate_r_visualization_code(consolidated_dag)

        # Save to output file
        with open(args.output_file, 'w') as file:
            file.write(r_code)

        if args.verbose:
            print(f"Processing complete. Output saved to {args.output_file}")

def main():
    parser = argparse.ArgumentParser(description='SemDAG Processor')
    
    # Required arguments
    parser.add_argument('--model', default='llama3.3:70b', help='Ollama model name')
    parser.add_argument('--input-file', default='SemDAG.R', help='Input R file path')
    parser.add_argument('--output-file', default='ConsolidatedDAG.R', help='Output R file path')
    
    # Processing options
    parser.add_argument('--consolidate', type=bool, default=True, help='Enable node consolidation')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    
    # Color scheme
    parser.add_argument('--color-primary', default='#E74C3C', help='Primary node color')
    parser.add_argument('--color-biological', default='#3498DB', help='Biological process color')
    parser.add_argument('--color-neural', default='#9B59B6', help='Neural node color')
    parser.add_argument('--color-molecular', default='#2ECC71', help='Molecular node color')
    parser.add_argument('--color-disease', default='#F39C12', help='Disease node color')
    parser.add_argument('--color-other', default='#95A5A6', help='Other node color')
    
    # Visualization parameters
    parser.add_argument('--viz-width', default='100%', help='Visualization width')
    parser.add_argument('--viz-height', default='900px', help='Visualization height')
    parser.add_argument('--font-size', type=int, default=18, help='Node font size')
    parser.add_argument('--edge-width', type=float, default=2.0, help='Edge width')
    parser.add_argument('--gravitational-constant', type=int, default=-200, help='Physics gravitational constant')
    parser.add_argument('--spring-length', type=int, default=250, help='Physics spring length')
    
    args = parser.parse_args()
    
    # Check if input file exists
    if not os.path.exists(args.input_file):
        print(f"Error: Input file '{args.input_file}' not found")
        return
    
    # Process the DAG
    processor = SemDAGProcessor(args)
    processor.process_semdag(args)

if __name__ == "__main__":
    main()