// Sombra macia embaixo de uma logo (usada como layer.effect).
import QtQuick
import QtQuick.Effects

MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, janela.escuro ? 0.55 : 0.3)
    shadowBlur: 0.7
    shadowVerticalOffset: Math.round(janela.gu * 0.2)
    shadowHorizontalOffset: 0
    autoPaddingEnabled: true
}
