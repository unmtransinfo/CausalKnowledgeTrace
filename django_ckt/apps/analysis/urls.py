"""
URL configuration for analysis app.
"""
from django.urls import path
from . import views

app_name = 'analysis'

urlpatterns = [
    path('', views.CausalAnalysisView.as_view(), name='causal'),
    path('api/graph-summary/', views.get_graph_summary, name='graph_summary'),
    path('api/total-cycles/', views.get_total_cycles, name='total_cycles'),
    path('api/variables/', views.get_dag_variables, name='variables'),
    path('api/causal-paths/', views.analyze_causal_paths, name='causal_paths'),
    # New pipeline-backed endpoints (stages 3-6)
    path('api/cycle-analysis/', views.get_cycle_analysis, name='cycle_analysis'),
    path('api/node-removal/', views.get_node_removal, name='node_removal'),
    path('api/post-removal/', views.get_post_removal, name='post_removal'),
    path('api/causal-inference/', views.get_causal_inference, name='causal_inference'),
    # Legacy endpoints (now backed by pipeline instead of heuristics)
    path('api/adjustment-sets/', views.calculate_adjustment_sets, name='adjustment_sets'),
    path('api/instrumental-variables/', views.find_instrumental_variables, name='instrumental_variables'),
]

