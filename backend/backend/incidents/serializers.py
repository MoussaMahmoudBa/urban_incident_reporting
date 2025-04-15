from rest_framework import serializers
from .models import Incident, OfflineIncident
from django.contrib.gis.geos import Point

class IncidentSerializer(serializers.ModelSerializer):
    location = serializers.SerializerMethodField()
    
    class Meta:
        model = Incident
        fields = ['id', 'user', 'incident_type', 'description', 'photo', 'audio', 'location', 'created_at']
        read_only_fields = ['user']

    def get_location(self, obj):
        # Convertit le Point GIS en string "lat,lng"
        if obj.location:
            return f"{obj.location.y},{obj.location.x}"
        return None

    def create(self, validated_data):
        # Convertit les coordonnées en Point si nécessaire
        if isinstance(validated_data.get('location'), str):
            try:
                lat, lon = map(float, validated_data['location'].split(','))
                validated_data['location'] = Point(lon, lat)
            except (ValueError, AttributeError):
                pass
        return super().create(validated_data)
    
class OfflineIncidentSerializer(serializers.ModelSerializer):
    class Meta:
        model = OfflineIncident
        fields = '__all__'