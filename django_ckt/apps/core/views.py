"""
Core views for CausalKnowledgeTrace.
"""
from django.shortcuts import render
from django.views.generic import TemplateView


class HomeView(TemplateView):
    """
    Home page view.
    """
    template_name = 'home.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Home - CKT'
        context['active_tab'] = 'home'
        return context


class AboutView(TemplateView):
    """
    About page view with application information and user guide.
    """
    template_name = 'about.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'About CKT - Causal Knowledge Trace'
        context['active_tab'] = 'about'
        return context

