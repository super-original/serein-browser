// Original controlled execution-world probe; no extension API or native access.
window.sereinMainWorldProbe = 'page-global';
document.documentElement.dataset.sereinMainWorldMarker = 'executed';
document.documentElement.dataset.sereinMainWorldObservedEnd = document.documentElement.dataset.sereinDocumentEndMarker || 'missing';
