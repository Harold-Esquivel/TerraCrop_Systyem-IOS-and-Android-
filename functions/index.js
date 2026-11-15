const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

initializeApp();

exports.sendCriticalAlert = onDocumentCreated(
  'users/{uid}/alerts/{alertId}',
  async (event) => {
    const alert = event.data?.data();
    if (!alert) return;
    const uid = event.params.uid;
    const userRef = getFirestore().collection('users').doc(uid);
    const user = await userRef.get();
    const token = user.data()?.fcmToken;
    if (!token) return;

    try {
      await getMessaging().send({
        token,
        notification: {title: alert.title, body: alert.body},
        data: {parcelAlert: event.params.alertId},
      });
    } catch (error) {
      if (error.code === 'messaging/registration-token-not-registered') {
        await userRef.update({fcmToken: null});
      } else {
        throw error;
      }
    }
  },
);
