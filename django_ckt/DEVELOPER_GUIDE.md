# Developer Guide - Django CausalKnowledgeTrace

Quick reference for developers working on the Django CKT project.

---

## Project Structure

```
django_ckt/
├── config/              # Django project configuration
├── apps/                # Django applications
│   ├── core/           # Core functionality, models, R interface
│   ├── visualization/  # Graph visualization
│   ├── analysis/       # Causal analysis
│   ├── upload/         # File upload
│   └── graph_config/   # Graph configuration
├── templates/          # HTML templates
├── static/             # Static files (CSS, JS, images)
├── media/              # User uploads
└── r_modules/          # R modules from shiny_app
```

---

## Quick Commands

### Setup
```bash
./setup_django.sh              # Full setup (first time)
```

### Running
```bash
./run_django.sh                # Run with auto-detected server
python manage.py runserver 0.0.0.0:3838  # Django dev server
daphne -b 0.0.0.0 -p 3838 config.asgi:application  # ASGI (Daphne)
uvicorn config.asgi:application --host 0.0.0.0 --port 3838  # ASGI (Uvicorn)
```

### Testing
```bash
python test_r_integration.py   # Test R integration
python manage.py test          # Run Django tests
python manage.py check         # Check for issues
```

### Database
```bash
python manage.py migrate       # Run migrations
python manage.py makemigrations  # Create migrations
python manage.py shell         # Django shell
```

### Utilities
```bash
python manage.py copy_r_modules  # Copy R modules from shiny_app
python manage.py collectstatic   # Collect static files
python manage.py createsuperuser # Create admin user
```

---

## Using the R Interface

### Basic Usage

```python
from apps.core.r_interface import get_r_interface

# Get R interface instance
r = get_r_interface()

# Load a DAG from file
result = r.load_dag_from_file('/path/to/dag.R')
dag_object = result['dag_object']

# Create network visualization data
network_data = r.create_network_data(dag_object)
nodes = network_data['nodes']
edges = network_data['edges']

# Calculate adjustment sets
adj_sets = r.calculate_adjustment_sets(
    dag_object, 
    exposure='X', 
    outcome='Y', 
    effect_type='total'
)

# Find instrumental variables
instruments = r.find_instrumental_variables(
    dag_object,
    exposure='X',
    outcome='Y'
)
```

### Available R Functions

- `load_dag_from_file(file_path)` - Load DAG from R file
- `create_network_data(dag_object)` - Create network data
- `calculate_adjustment_sets(dag, exposure, outcome, effect_type)` - Adjustment sets
- `find_instrumental_variables(dag, exposure, outcome)` - Instrumental variables
- `create_interactive_network(nodes, edges, physics_strength, force_full_display)` - visNetwork
- `generate_legend_html(nodes_df)` - Generate legend
- `search_cui(search_term, search_type, limit)` - Search CUI
- `remove_node(dag_object, node_id)` - Remove node
- `remove_edge(dag_object, from_node, to_node)` - Remove edge

---

## Database Models

### Core Models (Unmanaged - Existing Schema)

```python
from apps.core.models import Sentence, Predication, SubjectSearch, ObjectSearch

# Query sentences
sentences = Sentence.objects.filter(pmid='12345678')

# Query predications
predications = Predication.objects.filter(
    subject_cui='C0001234',
    object_cui='C0005678'
)

# Search CUIs
subjects = SubjectSearch.objects.filter(subject_name__icontains='diabetes')
objects = ObjectSearch.objects.filter(object_name__icontains='insulin')
```

### GraphFile Model (Managed - New)

```python
from apps.core.models import GraphFile

# Create new graph file record
graph = GraphFile.objects.create(
    name='My Graph',
    file_type='dagitty',
    file_path='/path/to/graph.R',
    node_count=100,
    edge_count=250
)
```

---

## Creating Views

### Template View Example

```python
from django.views.generic import TemplateView

class MyView(TemplateView):
    template_name = 'my_template.html'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['active_tab'] = 'my_tab'
        context['data'] = self.get_my_data()
        return context
    
    def get_my_data(self):
        # Your logic here
        return {}
```

### API View Example

```python
from django.http import JsonResponse
from django.views import View
from apps.core.r_interface import get_r_interface

class MyAPIView(View):
    def post(self, request):
        try:
            # Get data from request
            data = json.loads(request.body)
            
            # Use R interface
            r = get_r_interface()
            result = r.some_function(data['param'])
            
            return JsonResponse({
                'success': True,
                'data': result
            })
        except Exception as e:
            return JsonResponse({
                'success': False,
                'error': str(e)
            }, status=400)
```

---

## Creating Templates

### Basic Template

```html
{% extends 'base.html' %}

{% block title %}My Page - CKT{% endblock %}

{% block content %}
<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-header">
                <h3>My Page</h3>
            </div>
            <div class="card-body">
                <!-- Your content here -->
            </div>
        </div>
    </div>
</div>
{% endblock %}

{% block extra_js %}
<script>
    // Your JavaScript here
</script>
{% endblock %}
```

---

## Environment Variables

Edit `.env` file:

```bash
# Django
DJANGO_SECRET_KEY=your-secret-key
ENVIRONMENT=development

# Application
APP_PORT=3838

# Database
DB_HOST=localhost
DB_PORT=5433
DB_USER=rajesh
DB_PASSWORD=Software292$
DB_NAME=causalehr

# Database Tables
DB_SENTENCE_SCHEMA=public
DB_SENTENCE_TABLE=sentence
DB_PREDICATION_SCHEMA=public
DB_PREDICATION_TABLE=predication
DB_SUBJECT_SEARCH_SCHEMA=filtered
DB_SUBJECT_SEARCH_TABLE=subject_search
DB_OBJECT_SEARCH_SCHEMA=filtered
DB_OBJECT_SEARCH_TABLE=object_search
```

---

## Common Tasks

### Add a New App

```bash
python manage.py startapp myapp apps/myapp
```

Then add to `INSTALLED_APPS` in `config/settings.py`:
```python
INSTALLED_APPS = [
    # ...
    'apps.myapp',
]
```

### Add a New URL

In `apps/myapp/urls.py`:
```python
from django.urls import path
from . import views

app_name = 'myapp'

urlpatterns = [
    path('', views.MyView.as_view(), name='index'),
]
```

In `config/urls.py`:
```python
urlpatterns = [
    # ...
    path('myapp/', include('apps.myapp.urls')),
]
```

### Add Static Files

1. Place files in `static/css/`, `static/js/`, or `static/images/`
2. Run `python manage.py collectstatic`
3. Use in templates:
```html
{% load static %}
<link rel="stylesheet" href="{% static 'css/my-style.css' %}">
<script src="{% static 'js/my-script.js' %}"></script>
```

---

## Debugging

### Django Debug Toolbar (Optional)

```bash
pip install django-debug-toolbar
```

Add to `INSTALLED_APPS` and `MIDDLEWARE` in settings.py.

### Logging

Check logs in `../logs/django_app.log`

### Django Shell

```bash
python manage.py shell
```

```python
# Test database connection
from apps.core.models import Sentence
print(Sentence.objects.count())

# Test R interface
from apps.core.r_interface import get_r_interface
r = get_r_interface()
```

---

## Best Practices

1. **Always use the R interface wrapper** - Don't call R directly
2. **Handle errors gracefully** - Use try/except blocks
3. **Use Django ORM** - Don't write raw SQL unless necessary
4. **Follow Django conventions** - Use class-based views when possible
5. **Document your code** - Add docstrings to functions
6. **Test your changes** - Write tests for new features
7. **Use environment variables** - Don't hardcode sensitive data

---

## Resources

- **Django Documentation**: https://docs.djangoproject.com/en/5.0/
- **rpy2 Documentation**: https://rpy2.github.io/
- **Bootstrap 5**: https://getbootstrap.com/docs/5.3/
- **vis-network**: https://visjs.github.io/vis-network/docs/network/

---

## Getting Help

1. Check `QUICKSTART.md` for setup issues
2. Check `DJANGO_MIGRATION_STATUS.md` for known issues
3. Review Django logs in `../logs/django_app.log`
4. Test R integration with `python test_r_integration.py`
5. Create an issue on GitHub

---

**Happy coding! 🚀**

