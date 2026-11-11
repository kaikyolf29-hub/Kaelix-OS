// Calendário do mês, o mesmo do relógio do KDE (setinhas para trocar o mês).
import QtQuick
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmaCalendar.MonthView {
    property var hoje: new Date()

    today: hoje
    firstDayOfWeek: Qt.locale().firstDayOfWeek
    showWeekNumbers: false
    borderOpacity: 0.25
}
