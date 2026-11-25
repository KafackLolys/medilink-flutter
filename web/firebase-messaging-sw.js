// Firebase Messaging service worker for browser push notifications.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBKB0JkOOB94FreZlbLFnPl2gfzo1cFdx0',
  authDomain: 'medilink-2027.firebaseapp.com',
  projectId: 'medilink-2027',
  messagingSenderId: '353233115193',
  // Remplacer par l'App ID de l'application Web Firebase MediLink.
  appId: 'REPLACE_WITH_MEDILINK_FIREBASE_WEB_APP_ID',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  const title = data.title || 'Notification MedLink';
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url: data.url || '/' },
  };
  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  const url = event.notification.data && event.notification.data.url;
  event.notification.close();
  if (url && new URL(url, self.location.origin).origin === self.location.origin) {
    event.waitUntil(clients.openWindow(url));
  }
});
