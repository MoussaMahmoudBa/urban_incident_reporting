from rest_framework import serializers
from .models import Incident

class IncidentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Incident
        fields = ['id', 'user', 'incident_type', 'description', 'photo', 'location', 'created_at']
        read_only_fields = ['user']  # Le champ 'user' est en lecture seule