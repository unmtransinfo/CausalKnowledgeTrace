"""
Core views for CausalKnowledgeTrace.
"""
from django.shortcuts import render
from django.views.generic import TemplateView


class AboutView(TemplateView):
    """
    About page view with application information and user guide.
    This serves as both the home page and about page (consolidated).
    """
    template_name = 'about.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'About CKT - Causal Knowledge Trace'
        context['active_tab'] = 'about'
        return context

