// Firebase Messaging service worker for browser push notifications.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCsleSpykstnt2hApXxvejXAJTqhUM3HO0',
  authDomain: 'test-flutter-e5e37.firebaseapp.com',
  projectId: 'test-flutter-e5e37',
  messagingSenderId: '675953719483',
  appId: '1:675953719483:web:405c9ce6a229fb0ad8519e',
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
