
    // ----- Kaelix OS: botões de janela nas cores do sistema -----
    // Fechar (rosa), minimizar (azul claro) e tela cheia (verde água) são
    // bolinhas com o símbolo dentro. Os outros botões seguem o desenho do Breeze.
    {
        QColor kaelixFundo;
        QColor kaelixSimbolo;
        switch (type()) {
        case DecorationButtonType::Close:
            kaelixFundo = QColor(0xF0, 0x60, 0x9E);
            kaelixSimbolo = QColor(0x4A, 0x12, 0x30);
            break;
        case DecorationButtonType::Minimize:
            kaelixFundo = QColor(0x8F, 0xA2, 0xFF);
            kaelixSimbolo = QColor(0x1E, 0x2A, 0x66);
            break;
        case DecorationButtonType::Maximize:
            kaelixFundo = QColor(0x45, 0xD0, 0xC1);
            kaelixSimbolo = QColor(0x0B, 0x47, 0x40);
            break;
        default:
            break;
        }

        if (kaelixFundo.isValid()) {
            const auto kaelixDeco = qobject_cast<Decoration *>(decoration());
            const bool kaelixAtiva = kaelixDeco && kaelixDeco->window()->isActive();
            if (isPressed()) {
                kaelixFundo = kaelixFundo.darker(118);
            } else if (isHovered()) {
                kaelixFundo = kaelixFundo.lighter(110);
            } else if (!kaelixAtiva) {
                // Janela em segundo plano: os botões ficam mais apagados.
                kaelixFundo.setAlphaF(0.5);
                kaelixSimbolo.setAlphaF(0.6);
            }

            painter->setPen(Qt::NoPen);
            painter->setBrush(kaelixFundo);
            painter->drawEllipse(QRectF(1.5, 1.5, 15, 15));

            QPen kaelixPena(kaelixSimbolo);
            kaelixPena.setCapStyle(Qt::RoundCap);
            kaelixPena.setJoinStyle(Qt::RoundJoin);
            kaelixPena.setWidthF(1.4 * qMax((qreal)1.0, 20 / width));
            painter->setPen(kaelixPena);
            painter->setBrush(Qt::NoBrush);

            switch (type()) {
            case DecorationButtonType::Close:
                painter->drawLine(QPointF(6.4, 6.4), QPointF(11.6, 11.6));
                painter->drawLine(QPointF(11.6, 6.4), QPointF(6.4, 11.6));
                break;
            case DecorationButtonType::Minimize:
                painter->drawLine(QPointF(6, 9), QPointF(12, 9));
                break;
            default:
                if (isChecked()) {
                    // Janela em tela cheia: dois cantos apontando para dentro.
                    painter->drawPolyline(QVector<QPointF>{QPointF(5.8, 8.2), QPointF(8.2, 8.2), QPointF(8.2, 5.8)});
                    painter->drawPolyline(QVector<QPointF>{QPointF(12.2, 9.8), QPointF(9.8, 9.8), QPointF(9.8, 12.2)});
                } else {
                    // Dois cantos apontando para fora.
                    painter->drawPolyline(QVector<QPointF>{QPointF(6.4, 9.6), QPointF(6.4, 6.4), QPointF(9.6, 6.4)});
                    painter->drawPolyline(QVector<QPointF>{QPointF(11.6, 8.4), QPointF(11.6, 11.6), QPointF(8.4, 11.6)});
                }
                break;
            }
            return;
        }
    }
    // ----- fim da parte do Kaelix OS -----
