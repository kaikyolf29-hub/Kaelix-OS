
    // ----- Kaelix OS: botões de janela nas cores do sistema -----
    // Fechar (rosa), minimizar (azul claro) e tela cheia (verde água) são
    // bolinhas. Como no Mac, o símbolo de dentro só aparece quando o mouse
    // chega em qualquer uma das três: ele surge e cresce de leve, com um
    // pulinho no fim. Com a janela em segundo plano, as bolinhas ficam cinza
    // e ganham a cor quando o mouse chega. Os outros botões seguem o Breeze.
    {
        QColor kaelixFundo;
        QColor kaelixSimbolo;
        switch (type()) {
        case DecorationButtonType::Close:
            kaelixFundo = QColor(0xF0, 0x60, 0x9E);
            kaelixSimbolo = QColor(0x5A, 0x10, 0x36);
            break;
        case DecorationButtonType::Minimize:
            kaelixFundo = QColor(0x8F, 0xA2, 0xFF);
            kaelixSimbolo = QColor(0x1E, 0x2A, 0x6E);
            break;
        case DecorationButtonType::Maximize:
            kaelixFundo = QColor(0x45, 0xD0, 0xC1);
            kaelixSimbolo = QColor(0x0A, 0x4A, 0x42);
            break;
        default:
            break;
        }

        if (kaelixFundo.isValid()) {
            const auto kaelixDeco = qobject_cast<Decoration *>(decoration());
            const bool kaelixAtiva = kaelixDeco && kaelixDeco->window()->isActive();
            auto *kaelixEu = const_cast<Button *>(this);

            // Cada bolinha tem uma animação (0 = sem símbolo, 1 = símbolo
            // inteiro), criada no primeiro desenho. Ela ouve o mouse das três
            // bolinhas do mesmo lado da barra de título.
            auto *kaelixAnim = findChild<QVariantAnimation *>(QStringLiteral("kaelix-simbolo"), Qt::FindDirectChildrenOnly);
            if (!kaelixAnim) {
                kaelixAnim = new QVariantAnimation(kaelixEu);
                kaelixAnim->setObjectName(QStringLiteral("kaelix-simbolo"));
                kaelixAnim->setStartValue(0.0);
                kaelixAnim->setEndValue(0.0);
                QObject::connect(kaelixAnim, &QVariantAnimation::valueChanged, kaelixEu, [kaelixEu]() {
                    kaelixEu->update();
                });

                // Ao passar de uma bolinha para a outra, o mouse cruza o vão
                // entre elas: espera um instante antes de esconder os símbolos,
                // para não piscar.
                auto *kaelixSaida = new QTimer(kaelixEu);
                kaelixSaida->setSingleShot(true);
                kaelixSaida->setInterval(90);

                QObject *kaelixGrupo = kaelixEu->parent() ? kaelixEu->parent() : static_cast<QObject *>(kaelixEu->decoration());
                const auto kaelixDoGrupo = [kaelixGrupo]() {
                    QList<Button *> lista;
                    const auto filhos = kaelixGrupo->findChildren<Button *>();
                    for (Button *b : filhos) {
                        const auto t = b->type();
                        if (t == DecorationButtonType::Close || t == DecorationButtonType::Minimize || t == DecorationButtonType::Maximize) {
                            lista << b;
                        }
                    }
                    return lista;
                };
                const auto kaelixIrPara = [kaelixAnim, kaelixEu](qreal alvo) {
                    if (qFuzzyCompare(kaelixAnim->endValue().toReal() + 1.0, alvo + 1.0)) {
                        return;
                    }
                    const QVariant atual = kaelixAnim->currentValue();
                    const qreal agora = atual.isValid() ? atual.toReal() : 0.0;
                    const auto d = qobject_cast<Decoration *>(kaelixEu->decoration());
                    const bool anima = d && d->animationsDuration() > 0;
                    kaelixAnim->stop();
                    kaelixAnim->setStartValue(agora);
                    kaelixAnim->setEndValue(alvo);
                    // Aparecer com calma (220 ms) e sumir um pouco mais rápido (150 ms).
                    kaelixAnim->setDuration(anima ? qMax(1, int(qAbs(alvo - agora) * (alvo > agora ? 220 : 150))) : 0);
                    kaelixAnim->start();
                };
                const auto kaelixOlhar = [kaelixDoGrupo, kaelixIrPara, kaelixSaida]() {
                    bool algum = false;
                    const auto lista = kaelixDoGrupo();
                    for (Button *b : lista) {
                        algum = algum || b->isHovered();
                    }
                    if (algum) {
                        kaelixSaida->stop();
                        kaelixIrPara(1.0);
                    } else if (!kaelixSaida->isActive()) {
                        kaelixSaida->start();
                    }
                };
                QObject::connect(kaelixSaida, &QTimer::timeout, kaelixEu, [kaelixDoGrupo, kaelixIrPara]() {
                    const auto lista = kaelixDoGrupo();
                    for (Button *b : lista) {
                        if (b->isHovered()) {
                            return;
                        }
                    }
                    kaelixIrPara(0.0);
                });
                const auto lista = kaelixDoGrupo();
                for (Button *b : lista) {
                    QObject::connect(b, &KDecoration3::DecorationButton::hoveredChanged, kaelixEu, kaelixOlhar);
                }
            }

            const QVariant kaelixValor = kaelixAnim->currentValue();
            const qreal kaelixP = qBound(0.0, kaelixValor.isValid() ? kaelixValor.toReal() : 0.0, 1.0);
            const qreal kaelixVisivel = QEasingCurve(QEasingCurve::OutCubic).valueForProgress(kaelixP);
            QEasingCurve kaelixPulo(QEasingCurve::OutBack);
            kaelixPulo.setOvershoot(2.2);
            const qreal kaelixTamanho = 0.4 + 0.6 * kaelixPulo.valueForProgress(kaelixP);

            // Segundo plano: cinza discreto, que vira cor conforme o mouse chega.
            qreal kaelixCor = 1.0;
            if (!kaelixAtiva && kaelixDeco) {
                kaelixCor = kaelixVisivel;
                const QColor kaelixCinza = KColorUtils::mix(kaelixDeco->titleBarColor(), kaelixDeco->fontColor(), 0.26);
                kaelixFundo = KColorUtils::mix(kaelixCinza, kaelixFundo, kaelixCor);
            }
            if (isPressed()) {
                kaelixFundo = kaelixFundo.darker(120);
            }

            const qreal kaelixFino = qMax((qreal)1.0, 20 / width);
            painter->setPen(Qt::NoPen);
            painter->setBrush(kaelixFundo);
            painter->drawEllipse(QRectF(1.5, 1.5, 15, 15));

            // Contorno bem fino, um tom abaixo, para dar acabamento (como no Mac).
            if (kaelixCor > 0.01) {
                QPen kaelixBorda(QColor(0, 0, 0, int(40 * kaelixCor)));
                kaelixBorda.setWidthF(0.8 * kaelixFino);
                painter->setPen(kaelixBorda);
                painter->setBrush(Qt::NoBrush);
                painter->drawEllipse(QRectF(1.9, 1.9, 14.2, 14.2));
            }

            if (kaelixVisivel > 0.01) {
                painter->save();
                painter->setOpacity(painter->opacity() * kaelixVisivel);
                painter->translate(9, 9);
                painter->scale(kaelixTamanho, kaelixTamanho);
                painter->translate(-9, -9);

                QPen kaelixPena(kaelixSimbolo);
                kaelixPena.setCapStyle(Qt::RoundCap);
                kaelixPena.setJoinStyle(Qt::RoundJoin);
                kaelixPena.setWidthF(1.5 * kaelixFino);
                painter->setPen(kaelixPena);
                painter->setBrush(Qt::NoBrush);

                switch (type()) {
                case DecorationButtonType::Close:
                    painter->drawLine(QPointF(6.5, 6.5), QPointF(11.5, 11.5));
                    painter->drawLine(QPointF(11.5, 6.5), QPointF(6.5, 11.5));
                    break;
                case DecorationButtonType::Minimize:
                    painter->drawLine(QPointF(6, 9), QPointF(12, 9));
                    break;
                default:
                    // Tela cheia: dois triângulos cheios, como no Mac. Com a
                    // janela em tela cheia, eles apontam para dentro.
                    kaelixPena.setWidthF(0.8 * kaelixFino);
                    painter->setPen(kaelixPena);
                    painter->setBrush(kaelixSimbolo);
                    if (isChecked()) {
                        painter->drawPolygon(QPolygonF({QPointF(8.25, 5.25), QPointF(8.25, 8.25), QPointF(5.25, 8.25)}));
                        painter->drawPolygon(QPolygonF({QPointF(9.75, 12.75), QPointF(9.75, 9.75), QPointF(12.75, 9.75)}));
                    } else {
                        painter->drawPolygon(QPolygonF({QPointF(5.8, 5.8), QPointF(9, 5.8), QPointF(5.8, 9)}));
                        painter->drawPolygon(QPolygonF({QPointF(12.2, 12.2), QPointF(9, 12.2), QPointF(12.2, 9)}));
                    }
                    break;
                }
                painter->restore();
            }
            return;
        }
    }
    // ----- fim da parte do Kaelix OS -----
