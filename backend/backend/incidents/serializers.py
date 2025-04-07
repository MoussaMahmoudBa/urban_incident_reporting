from rest_framework import serializers
from .models import Incident, OfflineIncident
from django.contrib.gis.geos import Point

class IncidentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Incident
        fields = ['id', 'user', 'incident_type', 'description', 'photo', 'audio', 'location', 'created_at']
        read_only_fields = ['user']

    def create(self, validated_data):
        # Convertit les coordonnées en Point si nécessaire
        if isinstance(validated_data.get('location'), str):
            lat, lon = map(float, validated_data['location'].split(','))
            validated_data['location'] = Point(lon, lat)
        return super().create(validated_data)

class OfflineIncidentSerializer(serializers.ModelSerializer):
    class Meta:
        model = OfflineIncident
        fields = '__all__'