"""
Core models for CausalKnowledgeTrace.

These models represent the existing PostgreSQL database schema.
They are unmanaged (managed = False) to prevent Django from trying to create/modify tables.
"""
from django.db import models
from django.conf import settings
from django.contrib.postgres.fields import ArrayField


class Sentence(models.Model):
    """
    Represents sentences from the SemMedDB database.
    This is an unmanaged model pointing to the existing sentence table.
    """
    sentence_id = models.BigIntegerField(primary_key=True)
    pmid = models.BigIntegerField()
    type = models.CharField(max_length=50, blank=True, null=True)
    number = models.IntegerField(blank=True, null=True)
    sent_text = models.TextField(blank=True, null=True)
    sent_start_index = models.IntegerField(blank=True, null=True)
    sent_end_index = models.IntegerField(blank=True, null=True)
    section_header = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = f'"{settings.DB_CONFIG["SENTENCE_SCHEMA"]}"."{settings.DB_CONFIG["SENTENCE_TABLE"]}"'
        verbose_name = 'Sentence'
        verbose_name_plural = 'Sentences'

    def __str__(self):
        return f"Sentence {self.sentence_id} (PMID: {self.pmid})"


class Predication(models.Model):
    """
    Represents predications (relationships) from the SemMedDB database.
    This is an unmanaged model pointing to the existing predication table.
    """
    predication_id = models.BigIntegerField(primary_key=True)
    sentence_id = models.BigIntegerField()
    pmid = models.BigIntegerField()
    predicate = models.CharField(max_length=50)
    subject_cui = models.CharField(max_length=8)
    subject_name = models.CharField(max_length=255)
    subject_semtype = models.CharField(max_length=50)
    subject_novelty = models.IntegerField(blank=True, null=True)
    object_cui = models.CharField(max_length=8)
    object_name = models.CharField(max_length=255)
    object_semtype = models.CharField(max_length=50)
    object_novelty = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = f'"{settings.DB_CONFIG["PREDICATION_SCHEMA"]}"."{settings.DB_CONFIG["PREDICATION_TABLE"]}"'
        verbose_name = 'Predication'
        verbose_name_plural = 'Predications'

    def __str__(self):
        return f"{self.subject_name} {self.predicate} {self.object_name}"


class SubjectSearch(models.Model):
    """
    Represents the subject search index table.
    This is an unmanaged model pointing to the existing subject_search table.
    """
    cui = models.CharField(max_length=8, primary_key=True)
    name = models.CharField(max_length=255)
    semtype = ArrayField(models.CharField(max_length=50), blank=True, null=True)
    semtype_definition = ArrayField(models.TextField(), blank=True, null=True)

    class Meta:
        managed = False
        db_table = f'"{settings.DB_CONFIG["SUBJECT_SEARCH_SCHEMA"]}"."{settings.DB_CONFIG["SUBJECT_SEARCH_TABLE"]}"'
        verbose_name = 'Subject Search'
        verbose_name_plural = 'Subject Searches'

    def __str__(self):
        return f"{self.name} ({self.cui})"


class ObjectSearch(models.Model):
    """
    Represents the object search index table.
    This is an unmanaged model pointing to the existing object_search table.
    """
    cui = models.CharField(max_length=8, primary_key=True)
    name = models.CharField(max_length=255)
    semtype = ArrayField(models.CharField(max_length=50), blank=True, null=True)
    semtype_definition = ArrayField(models.TextField(), blank=True, null=True)

    class Meta:
        managed = False
        db_table = f'"{settings.DB_CONFIG["OBJECT_SEARCH_SCHEMA"]}"."{settings.DB_CONFIG["OBJECT_SEARCH_TABLE"]}"'
        verbose_name = 'Object Search'
        verbose_name_plural = 'Object Searches'

    def __str__(self):
        return f"{self.name} ({self.cui})"


class GraphFile(models.Model):
    """
    Represents uploaded or generated graph files.
    This is a managed model for tracking graph files in the Django application.
    """
    name = models.CharField(max_length=255)
    file_path = models.FileField(upload_to='graphs/')
    uploaded_at = models.DateTimeField(auto_now_add=True)
    file_type = models.CharField(max_length=10, choices=[('R', 'R Script'), ('RDS', 'RDS Binary')])
    description = models.TextField(blank=True, null=True)
    node_count = models.IntegerField(default=0)
    edge_count = models.IntegerField(default=0)

    class Meta:
        managed = True
        ordering = ['-uploaded_at']
        verbose_name = 'Graph File'
        verbose_name_plural = 'Graph Files'

    def __str__(self):
        return f"{self.name} ({self.node_count} nodes, {self.edge_count} edges)"

