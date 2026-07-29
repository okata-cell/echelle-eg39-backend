// Dummy reminderService - exports just placeholders so server doesn't crash
module.exports = {
  checkAndNotifyAdmin: async () => { console.log('checkAndNotifyAdmin: no-op'); },
  startReminderCron: () => { console.log('startReminderCron: no-op'); },
  getPendingLocations: async (hours) => { return []; },
  getPendingDemandes: async (hours) => { return []; }
};
console.log('✅ reminderService loaded (dummy)');
