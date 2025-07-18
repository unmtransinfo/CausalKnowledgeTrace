from langchain.llms import Ollama
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
import re
import json
import os

class SemDAGProcessor:
    def __init__(self):
        # Initialize Ollama with the specified model
        self.llm = Ollama(model="llama3.3:70b")

        # Define node consolidation rules
        self.consolidation_rules = {
            # Disease/Condition categories
            "cardiac": ["cardiac", "heart", "myocardial", "coronary"],
            "neuro": ["neurological", "brain", "neural", "cognitive"],
            "inflammation": ["inflammation", "inflammatory", "itis"],
            "vascular": ["vascular", "arterial", "venous"],
            "metabolic": ["metabolic", "diabetes", "insulin"],

            # Process categories
            "death": ["death", "mortality", "fatal"],
            "injury": ["injury", "trauma", "damage"],
            "infection": ["infection", "infectious", "bacterial", "viral"],

            # Generic nodes to remove
            "generic_nodes": [
                "disease", "disorder", "syndrome", "pathology", "condition",
                "process", "pathway", "mechanism", "response", "effect",
                "assessment", "evaluation", "procedure", "therapy", "treatment"
            ]
        }

        # Define prompt templates
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
            font.size = 16,
            font.color = "black",
            stringsAsFactors = FALSE
        )

        # Define color scheme
        color_scheme <- list(
            Primary = "#FF6B6B",
            Biological_Process = "#4ECDC4",
            Neural = "#45B7D1",
            Molecular = "#96CEB4",
            Disease = "#D4A5A5",
            Other = "#A9B7C0"
        )

        nodes$color <- unlist(color_scheme[nodes$group])

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
            return self.apply_consolidations(dag_definition, recommendations)
        except json.JSONDecodeError:
            print("Error parsing LLM response")
            return dag_definition

    def apply_consolidations(self, dag_definition, recommendations):
        """Apply the recommended consolidations and removals"""
        modified_dag = dag_definition

        # Apply consolidations
        for consolidation in recommendations.get('consolidations', []):
            for synonym in consolidation['synonyms']:
                modified_dag = modified_dag.replace(synonym, consolidation['main_term'])

        # Remove generic nodes
        for node in recommendations.get('removals', []):
            # Remove node and its edges
            lines = modified_dag.split('\n')
            lines = [line for line in lines if node not in line]
            modified_dag = '\n'.join(lines)

        return modified_dag

    def process_semdag(self, input_file, output_file):
        """Main processing function"""
        print("Processing SemDAG file...")

        # Extract DAG definition
        dag_definition = self.extract_dag_definition(input_file)
        if not dag_definition:
            print("Error: Could not extract DAG definition")
            return

        print("Consolidating nodes...")
        # Consolidate nodes
        consolidated_dag = self.consolidate_nodes(dag_definition)

        print("Generating visualization code...")
        # Generate R visualization code
        r_code = self.generate_r_visualization_code(consolidated_dag)

        # Save to output file
        with open(output_file, 'w') as file:
            file.write(r_code)

        print(f"Processing complete. Output saved to {output_file}")

def main():
    processor = SemDAGProcessor()

    # Example usage
    input_file = "SemDAG.R"
    output_file = "ConsolidatedDAG.R"

    if os.path.exists(input_file):
        processor.process_semdag(input_file, output_file)
    else:
        print(f"Error: Input file {input_file} not found")

if __name__ == "__main__":
    main()
