from rest_framework import generics
from .models import Incident
from .serializers import IncidentSerializer
from rest_framework.permissions import IsAuthenticated

class IncidentListCreateView(generics.ListCreateAPIView):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer
    permission_classes = [IsAuthenticated]  # Seuls les utilisateurs authentifiés peuvent créer un incident
    def perform_create(self, serializer):
        # Associe l'utilisateur authentifié à l'incident créé
        serializer.save(user=self.request.user)

class IncidentDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer

