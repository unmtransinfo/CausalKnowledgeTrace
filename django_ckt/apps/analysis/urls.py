"""
URL configuration for analysis app.
"""
from django.urls import path
from . import views

app_name = 'analysis'

urlpatterns = [
    path('', views.CausalAnalysisView.as_view(), name='causal'),
    path('api/graph-summary/', views.get_graph_summary, name='graph_summary'),
    path('api/adjustment-sets/', views.calculate_adjustment_sets, name='adjustment_sets'),
    path('api/instrumental-variables/', views.find_instrumental_variables, name='instrumental_variables'),
    path('api/causal-paths/', views.analyze_causal_paths, name='causal_paths'),
    path('api/variables/', views.get_dag_variables, name='variables'),
]

