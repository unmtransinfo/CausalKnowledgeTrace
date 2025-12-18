#!/usr/bin/env python3
"""
Timing Wrapper for Graph Creation
Adds detailed timing output to the graph creation process
"""

import sys
import time
from cli_interface import main as original_main, parse_arguments, validate_arguments, create_analysis_configuration
from analysis_core import GraphAnalyzer, MarkovBlanketAnalyzer

def display_timing_breakdown(timing_data):
    """Display detailed timing breakdown"""
    print("\n" + "="*80)
    print("⏱️  DETAILED TIMING BREAKDOWN")
    print("="*80)
    
    if not timing_data:
        print("No timing data available")
        return
    
    # Sort by duration (descending)
    sorted_timings = sorted(timing_data.items(), key=lambda x: x[1].get('duration', 0), reverse=True)
    
    total_time = timing_data.get('total_execution', {}).get('duration', 0)
    
    print(f"\n{'Step':<45} {'Time (s)':<12} {'% of Total':<12}")
    print("-" * 80)
    
    for step_name, step_data in sorted_timings:
        duration = step_data.get('duration', 0)
        percentage = (duration / total_time * 100) if total_time > 0 else 0
        print(f"{step_name:<45} {duration:>10.2f}s  {percentage:>10.1f}%")
    
    print("-" * 80)
    print(f"{'TOTAL':<45} {total_time:>10.2f}s  {100.0:>10.1f}%")
    print("="*80)
    
    # Identify bottlenecks
    print("\n🔍 BOTTLENECK ANALYSIS:")
    print("-" * 80)
    
    bottlenecks = [(name, data['duration']) for name, data in sorted_timings 
                   if name != 'total_execution' and data.get('duration', 0) > total_time * 0.05]
    
    if bottlenecks:
        print("Steps taking more than 5% of total time:")
        for name, duration in bottlenecks:
            percentage = (duration / total_time * 100) if total_time > 0 else 0
            print(f"  • {name}: {duration:.2f}s ({percentage:.1f}%)")
    else:
        print("No major bottlenecks detected (all steps < 5% of total time)")
    
    print("="*80)

def main_with_timing():
    """Main function with timing display"""
    try:
        args = parse_arguments()
        validate_arguments(args)
        
        # Create analysis configuration
        config_result = create_analysis_configuration(args)
        if len(config_result) == 4:
            db_config, config_name, threshold, yaml_config_data = config_result
        else:
            db_config, threshold = config_result
            config_name = args.config
            yaml_config_data = None
        
        # Get degree from args or YAML
        degree = args.degree
        if yaml_config_data and 'degree' in yaml_config_data:
            degree = yaml_config_data['degree']
        
        if args.markov_blanket:
            analyzer = MarkovBlanketAnalyzer(
                config_name=config_name,
                db_params=db_config,
                threshold=threshold,
                output_dir=args.output_dir,
                yaml_config_data=yaml_config_data,
                degree=degree
            )
            timing_results = analyzer.run_markov_blanket_analysis()
            if isinstance(timing_results, dict) and "error" in timing_results:
                sys.exit(1)
            analyzer.display_markov_blanket_summary()
        else:
            analyzer = GraphAnalyzer(
                config_name=config_name,
                db_params=db_config,
                threshold=threshold,
                output_dir=args.output_dir,
                yaml_config_data=yaml_config_data,
                degree=degree
            )
            timing_results = analyzer.run_analysis()
            if isinstance(timing_results, dict) and "error" in timing_results:
                sys.exit(1)
            analyzer.display_results_summary()
        
        # Display timing breakdown
        display_timing_breakdown(timing_results)
        
    except KeyboardInterrupt:
        print("\nAnalysis interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        if args.verbose if 'args' in locals() else False:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main_with_timing()

