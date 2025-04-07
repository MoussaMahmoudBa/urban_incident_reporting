from django.urls import path
from .views import IncidentListCreateView, IncidentDetailView, SyncOfflineIncidentsView

urlpatterns = [
    path('', IncidentListCreateView.as_view(), name='incident-list-create'),
    path('<int:pk>/', IncidentDetailView.as_view(), name='incident-detail'),
    path('sync/', SyncOfflineIncidentsView.as_view(), name='sync-offline-incidents'),
]