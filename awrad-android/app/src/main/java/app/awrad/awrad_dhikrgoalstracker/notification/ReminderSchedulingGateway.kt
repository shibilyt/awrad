package app.awrad.awrad_dhikrgoalstracker.notification

interface ReminderSchedulingGateway {
    fun canScheduleExactAlarms(): Boolean
    fun rescheduleAll()
}
