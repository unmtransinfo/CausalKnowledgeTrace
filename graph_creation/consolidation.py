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
        """Extract DAG definition from simplified R file"""
        with open(r_file_path, 'r') as file:
            content = file.read()
            # Updated regex to match the simplified format: g <- dagitty('dag { ... }')
            match = re.search(r"g\s*<-\s*dagitty\s*\(\s*['\"]dag\s*{\s*(.*?)\s*}\s*['\"]", content, re.DOTALL)
            if match:
                return match.group(1).strip()
            return None

    def generate_simplified_dag(self, dag_definition: str) -> str:
        """Generate simplified DAG definition in the same format"""
        return f"g <- dagitty('dag {{\n{dag_definition}\n}}')"

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
            main_term = consolidation.get('main_term', '')
            synonyms = consolidation.get('synonyms', [])
            for synonym in synonyms:
                if synonym != main_term:
                    modified_dag = modified_dag.replace(synonym, main_term)

        # Remove generic nodes and their edges
        for node in recommendations.get('removals', []):
            lines = modified_dag.split('\n')
            # Remove lines containing the node (both as standalone and in edges)
            lines = [line for line in lines if node not in line]
            modified_dag = '\n'.join(lines)

        return modified_dag

    def clean_dag_structure(self, dag_definition: str) -> str:
        """Clean up the DAG structure by removing duplicates and empty lines"""
        lines = dag_definition.split('\n')
        
        # Remove empty lines and duplicates while preserving order
        seen = set()
        cleaned_lines = []
        
        for line in lines:
            line = line.strip()
            if line and line not in seen:
                seen.add(line)
                cleaned_lines.append(' ' + line)  # Add space for proper indentation
        
        return '\n'.join(cleaned_lines)

    def process_semdag(self, args):
        """Main processing function"""
        if args.verbose:
            print(f"Processing SemDAG file: {args.input_file}")

        # Extract DAG definition
        dag_definition = self.extract_dag_definition(args.input_file)
        if not dag_definition:
            print("Error: Could not extract DAG definition from input file")
            print("Expected format: g <- dagitty('dag { ... }')")
            return

        if args.verbose:
            print(f"Extracted DAG with {len(dag_definition.split())} elements")

        if args.consolidate:
            if args.verbose:
                print("Consolidating nodes using LLM...")
            consolidated_dag = self.consolidate_nodes(dag_definition)
        else:
            consolidated_dag = dag_definition

        # Clean up the structure
        if args.verbose:
            print("Cleaning DAG structure...")
        cleaned_dag = self.clean_dag_structure(consolidated_dag)

        # Generate the simplified output
        final_output = self.generate_simplified_dag(cleaned_dag)

        # Save to output file
        with open(args.output_file, 'w') as file:
            file.write(final_output)

        if args.verbose:
            print(f"Processing complete. Output saved to {args.output_file}")
            print(f"Final DAG contains {len(cleaned_dag.split())} elements")

def main():
    parser = argparse.ArgumentParser(
        description='SemDAG Processor - Consolidates and cleans DAG files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  python semdag_processor.py --input-file degree_1.R --output-file CleanedDAG.R
  python semdag_processor.py --input-file MarkovBlanket_Union.R --output-file ConsolidatedMB.R --verbose
  python semdag_processor.py --input-file degree_2.R --no-consolidate --output-file SimpleClean.R
        """
    )
    
    # Required arguments
    parser.add_argument('--model', default='llama3.3:70b', help='Ollama model name (default: llama3.3:70b)')
    parser.add_argument('--input-file', default='SemDAG.R', help='Input R file path (default: SemDAG.R)')
    parser.add_argument('--output-file', default='ConsolidatedDAG.R', help='Output R file path (default: ConsolidatedDAG.R)')
    
    # Processing options
    parser.add_argument('--consolidate', dest='consolidate', action='store_true', 
                       help='Enable node consolidation using LLM (default)')
    parser.add_argument('--no-consolidate', dest='consolidate', action='store_false',
                       help='Disable node consolidation')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    
    # Set default for consolidate
    parser.set_defaults(consolidate=True)
    
    args = parser.parse_args()
    
    # Check if input file exists
    if not os.path.exists(args.input_file):
        print(f"Error: Input file '{args.input_file}' not found")
        return
    
    # Validate Ollama model availability if consolidation is enabled
    if args.consolidate:
        try:
            if args.verbose:
                print(f"Testing connection to Ollama model: {args.model}")
            test_llm = Ollama(model=args.model)
            # Simple test to verify model is available
            test_response = test_llm("Test")
            if args.verbose:
                print("✓ Ollama model connection successful")
        except Exception as e:
            print(f"Error: Cannot connect to Ollama model '{args.model}': {e}")
            print("Please ensure Ollama is running and the model is available")
            return
    
    # Process the DAG
    processor = SemDAGProcessor(args)
    processor.process_semdag(args)

if __name__ == "__main__":
    main()