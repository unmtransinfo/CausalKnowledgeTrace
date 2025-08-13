from langchain.llms import Ollama
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
import re
import json
import os

class SemDAGProcessor:
    def __init__(self):
        # Initialize Ollama with the specified model
        self.llm = Ollama(model="mistral")

        # Define node consolidation rules - UMLS-style synonyms
        self.consolidation_rules = {
            # Medical concept synonyms as found in UMLS
            "alzheimer_disease": ["alzheimer_disease", "alzheimers_disease", "alzheimer's_disease", "dementia_alzheimer_type", "alzheimer_dementia"],
            "hypertension": ["hypertension", "high_blood_pressure", "arterial_hypertension", "elevated_blood_pressure", "hbp"],
            "diabetes_mellitus": ["diabetes_mellitus", "diabetes", "dm", "diabetes_mellitus_type_2", "t2dm", "type_2_diabetes"],
            "myocardial_infarction": ["myocardial_infarction", "heart_attack", "mi", "acute_myocardial_infarction", "ami"],
            "cerebrovascular_accident": ["cerebrovascular_accident", "stroke", "cva", "brain_attack", "cerebral_stroke"],
            "beta_amyloid": ["beta_amyloid", "amyloid_beta", "abeta", "amyloid_beta_peptide", "beta_amyloid_peptide", "a_beta"],
            "neurofibrillary_tangles": ["neurofibrillary_tangles", "nft", "neurofibrillary_tangle", "tau_tangles", "tau_neurofibrillary_tangles"],
            "apolipoprotein_e": ["apolipoprotein_e", "apoe", "apo_e", "apolipoprotein_e4", "apoe4"],
            "acetylcholine": ["acetylcholine", "ach", "acetyl_choline"],
            "acetylcholinesterase": ["acetylcholinesterase", "ache", "acetylcholine_esterase", "cholinesterase"],
            "oxidative_stress": ["oxidative_stress", "reactive_oxygen_species", "ros", "oxygen_free_radicals"],
            "neuroinflammation": ["neuroinflammation", "brain_inflammation", "neural_inflammation", "cns_inflammation"],
            "cognitive_impairment": ["cognitive_impairment", "cognitive_decline", "cognitive_dysfunction", "mental_impairment"],
            "blood_brain_barrier": ["blood_brain_barrier", "bbb", "blood_cerebrospinal_fluid_barrier"],
            "microglia": ["microglia", "microglial_cells", "brain_macrophages"],
            
            # Generic nodes to remove (only truly generic terms)
            "generic_nodes": [
                "disease", "disorder", "syndrome", "pathology", "condition",
                "process", "pathway", "mechanism", "response", "effect"
            ]
        }

        # Define prompt templates
        self.node_consolidation_prompt = PromptTemplate(
            input_variables=["dag_content"],
            template="""
            Analyze this DAG content and identify only TRUE SYNONYMS that should be consolidated.
            Do NOT group related but distinct concepts together.
            
            Guidelines:
            - Only consolidate nodes that refer to the exact same entity/concept
            - Keep granular, specific terms separate (e.g., don't merge "heart disease" with "stroke")
            - Focus on different spellings, abbreviations, or naming conventions of the same thing
            - Preserve distinct biological processes, diseases, and molecular entities
            
            Return a JSON with two lists:
            1. 'consolidations': [{{"main_term": "preferred_name", "synonyms": ["synonym1", "synonym2"]}}]
            2. 'removals': ["overly_generic_term1", "overly_generic_term2"]

            DAG Content:
            {dag_content}
            """
        )

    def extract_dag_definition(self, r_file_path):
        """Extract DAG definition from R file"""
        with open(r_file_path, 'r') as file:
            content = file.read()
        # Find content between dag { and }
        match = re.search(r'dag\s*{(.*?)}', content, re.DOTALL)
        if match:
            return match.group(1).strip()
        return None

    def generate_r_visualization_code(self, dag_definition):
        """Generate R code for interactive visualization"""
        r_code = f"""
library(dagitty)
library(igraph)
library(visNetwork)
library(dplyr)

g <- dagitty('dag {{
{dag_definition}
}}')

# Create nodes dataframe using standardized three-category system
nodes <- data.frame(
    id = V(dagitty2graph(g))$name,
    label = gsub("_", " ", V(dagitty2graph(g))$name),
    font.size = 16,
    font.color = "black",
    stringsAsFactors = FALSE
)

# Categorize nodes based on DAG properties (exposure/outcome) or as "Other"
categorize_node <- function(node_name, dag_object) {
    # Extract exposure and outcome from dagitty object if available
    exposures <- character(0)
    outcomes <- character(0)

    if (!is.null(dag_object)) {
        exposures <- tryCatch(exposures(dag_object), error = function(e) character(0))
        outcomes <- tryCatch(outcomes(dag_object), error = function(e) character(0))
    }

    # Check if node is marked as exposure or outcome in the DAG
    if (length(exposures) > 0 && node_name %in% exposures) return("Exposure")
    if (length(outcomes) > 0 && node_name %in% outcomes) return("Outcome")

    # All other nodes are categorized as "Other"
    return("Other")
}

# Apply categorization
nodes$group <- sapply(nodes$id, function(x) categorize_node(x, g))

# Define standardized three-category color scheme
color_scheme <- list(
    Exposure = "#FF4500",    # Bright orange-red for exposure (highly contrasting)
    Outcome = "#0066CC",     # Bright blue for outcome (highly contrasting)
    Other = "#808080"        # Gray for all other nodes
)

# Apply colors based on group
nodes$color <- sapply(nodes$group, function(g) {
    if (g %in% names(color_scheme)) {
        return(color_scheme[[g]])
    } else {
        return("#808080")  # Default gray
    }
})

# Create edges dataframe
edges <- data.frame(
    from = get.edgelist(dagitty2graph(g))[,1],
    to = get.edgelist(dagitty2graph(g))[,2],
    arrows = "to",
    smooth = TRUE,
    width = 1.5,
    color = "#2F4F4F80",
    stringsAsFactors = FALSE
)

# Create interactive visualization
visNetwork(nodes, edges, width = "100%", height = "800px") %>%
    visPhysics(
        solver = "forceAtlas2Based",
        forceAtlas2Based = list(
            gravitationalConstant = -150,
            centralGravity = 0.01,
            springLength = 200,
            springConstant = 0.08,
            damping = 0.4,
            avoidOverlap = 1
        )
    ) %>%
    visOptions(
        highlightNearest = list(enabled = TRUE, degree = 1),
        nodesIdSelection = TRUE
    ) %>%
    visNodes(
        shadow = TRUE,
        font = list(size = 20, strokeWidth = 2)
    ) %>%
    visEdges(
        smooth = list(enabled = TRUE, type = "curvedCW")
    )
"""
        return r_code

    def consolidate_nodes(self, dag_definition):
        """Use LangChain to identify and consolidate nodes"""
        chain = LLMChain(llm=self.llm, prompt=self.node_consolidation_prompt)
        response = chain.run(dag_content=dag_definition)

        try:
            recommendations = json.loads(response)
            
            # Print consolidation summary
            if recommendations.get('consolidations'):
                print("Applying consolidations:")
                for consolidation in recommendations['consolidations']:
                    synonyms = ", ".join(consolidation['synonyms'])
                    print(f"  - Consolidating [{synonyms}] -> {consolidation['main_term']}")
            
            if recommendations.get('removals'):
                print("Removing generic nodes:")
                for node in recommendations['removals']:
                    print(f"  - Removing: {node}")
            
            return self.apply_consolidations(dag_definition, recommendations)
        except json.JSONDecodeError:
            print("Error parsing LLM response, applying rule-based consolidation...")
            # Fallback to rule-based consolidation
            return self.apply_rule_based_consolidation(dag_definition)

    def apply_rule_based_consolidation(self, dag_definition):
        """Fallback method using predefined rules"""
        # Parse the current DAG structure
        nodes, edges = self.parse_dag_structure(dag_definition)
        
        # Create mapping based on predefined rules
        node_mapping = {}
        
        for main_term, synonyms in self.consolidation_rules.items():
            if main_term != "generic_nodes":
                for synonym in synonyms:
                    if synonym in nodes:
                        node_mapping[synonym] = main_term
        
        # Apply the mapping
        recommendations = {
            'consolidations': [{'main_term': main_term, 'synonyms': synonyms} 
                             for main_term, synonyms in self.consolidation_rules.items() 
                             if main_term != "generic_nodes"],
            'removals': self.consolidation_rules.get('generic_nodes', [])
        }
        
        return self.apply_consolidations(dag_definition, recommendations)

    def parse_dag_structure(self, dag_definition):
        """Parse DAG to extract nodes and edges"""
        lines = [line.strip() for line in dag_definition.split('\n') if line.strip()]
        nodes = set()
        edges = []
        
        for line in lines:
            # Match edge patterns like "A -> B" or "A <- B"
            if '->' in line:
                parts = line.split('->')
                if len(parts) == 2:
                    source = parts[0].strip()
                    target = parts[1].strip()
                    nodes.add(source)
                    nodes.add(target)
                    edges.append((source, target))
            elif '<-' in line:
                parts = line.split('<-')
                if len(parts) == 2:
                    target = parts[0].strip()
                    source = parts[1].strip()
                    nodes.add(source)
                    nodes.add(target)
                    edges.append((source, target))
            elif line and not line.startswith('#'):
                # Single node declaration
                nodes.add(line)
        
        return nodes, edges

    def apply_consolidations(self, dag_definition, recommendations):
        """Apply consolidations while preserving all edges"""
        # Parse the current DAG structure
        nodes, edges = self.parse_dag_structure(dag_definition)
        
        # Create mapping from old names to new names
        node_mapping = {}
        
        # Apply consolidations
        for consolidation in recommendations.get('consolidations', []):
            main_term = consolidation['main_term']
            for synonym in consolidation['synonyms']:
                if synonym in nodes:
                    node_mapping[synonym] = main_term
        
        # Remove generic nodes
        nodes_to_remove = set(recommendations.get('removals', []))
        
        # Update nodes
        updated_nodes = set()
        for node in nodes:
            if node not in nodes_to_remove:
                new_name = node_mapping.get(node, node)
                updated_nodes.add(new_name)
        
        # Update edges, preserving all connections
        updated_edges = []
        for source, target in edges:
            # Skip edges involving removed nodes
            if source in nodes_to_remove or target in nodes_to_remove:
                continue
                
            new_source = node_mapping.get(source, source)
            new_target = node_mapping.get(target, target)
            
            # Avoid self-loops that might result from consolidation
            if new_source != new_target:
                edge_tuple = (new_source, new_target)
                if edge_tuple not in updated_edges:  # Avoid duplicates
                    updated_edges.append(edge_tuple)
        
        # Reconstruct DAG definition
        dag_lines = []
        
        # Add edges
        for source, target in updated_edges:
            dag_lines.append(f"{source} -> {target}")
        
        # Add isolated nodes (nodes with no edges)
        nodes_in_edges = set()
        for source, target in updated_edges:
            nodes_in_edges.add(source)
            nodes_in_edges.add(target)
        
        isolated_nodes = updated_nodes - nodes_in_edges
        for node in sorted(isolated_nodes):
            dag_lines.append(node)
        
        return '\n'.join(dag_lines)

    def process_semdag(self, input_file, output_file):
        """Main processing function"""
        print("Processing SemDAG file...")

        # Extract DAG definition
        dag_definition = self.extract_dag_definition(input_file)
        if not dag_definition:
            print("Error: Could not extract DAG definition")
            return

        # Parse original structure for comparison
        original_nodes, original_edges = self.parse_dag_structure(dag_definition)
        print(f"Original DAG: {len(original_nodes)} nodes, {len(original_edges)} edges")

        print("\nConsolidating nodes...")
        # Consolidate nodes
        consolidated_dag = self.consolidate_nodes(dag_definition)

        # Parse consolidated structure
        consolidated_nodes, consolidated_edges = self.parse_dag_structure(consolidated_dag)
        print(f"Consolidated DAG: {len(consolidated_nodes)} nodes, {len(consolidated_edges)} edges")

        print("\nGenerating visualization code...")
        # Generate R visualization code
        r_code = self.generate_r_visualization_code(consolidated_dag)

        # Save to output file
        with open(output_file, 'w') as file:
            file.write(r_code)

        print(f"\nProcessing complete. Output saved to {output_file}")
        print("Edge preservation: All relationships from consolidated nodes have been retained.")

def main():
    processor = SemDAGProcessor()

    # Example usage
    # input_file = "dag/causalWeb/degree_1.R"
    input_file = "degree_1.R"
    output_file = "ConsolidatedDAG.R"

    if os.path.exists(input_file):
        processor.process_semdag(input_file, output_file)
    else:
        print(f"Error: Input file {input_file} not found")

if __name__ == "__main__":
    main()
