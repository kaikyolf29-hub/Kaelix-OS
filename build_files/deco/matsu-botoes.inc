
    // ----- Matsu OS: botões de janela nas cores do sistema -----
    // Fechar (rosa), minimizar (azul claro) e tela cheia (verde água) são
    // bolinhas. Como no Mac, o símbolo de dentro só aparece quando o mouse
    // chega em qualquer uma das três: ele surge e cresce de leve, com um
    // pulinho no fim. Com a janela em segundo plano, as bolinhas ficam cinza
    // e ganham a cor quando o mouse chega. Os outros botões seguem o Breeze.
    {
        QColor matsuFundo;
        QColor matsuSimbolo;
        switch (type()) {
        case DecorationButtonType::Close:
            matsuFundo = QColor(0xF0, 0x60, 0x9E);
            matsuSimbolo = QColor(0x5A, 0x10, 0x36);
            break;
        case DecorationButtonType::Minimize:
            matsuFundo = QColor(0x8F, 0xA2, 0xFF);
            matsuSimbolo = QColor(0x1E, 0x2A, 0x6E);
            break;
        case DecorationButtonType::Maximize:
            matsuFundo = QColor(0x45, 0xD0, 0xC1);
            matsuSimbolo = QColor(0x0A, 0x4A, 0x42);
            break;
        default:
            break;
        }

        if (matsuFundo.isValid()) {
            const auto matsuDeco = qobject_cast<Decoration *>(decoration());
            const bool matsuAtiva = matsuDeco && matsuDeco->window()->isActive();
            auto *matsuEu = const_cast<Button *>(this);

            // Cada bolinha tem uma animação (0 = sem símbolo, 1 = símbolo
            // inteiro), criada no primeiro desenho. Ela ouve o mouse das três
            // bolinhas do mesmo lado da barra de título.
            auto *matsuAnim = findChild<QVariantAnimation *>(QStringLiteral("matsu-simbolo"), Qt::FindDirectChildrenOnly);
            if (!matsuAnim) {
                matsuAnim = new QVariantAnimation(matsuEu);
                matsuAnim->setObjectName(QStringLiteral("matsu-simbolo"));
                matsuAnim->setStartValue(0.0);
                matsuAnim->setEndValue(0.0);
                QObject::connect(matsuAnim, &QVariantAnimation::valueChanged, matsuEu, [matsuEu]() {
                    matsuEu->update();
                });

                // Ao passar de uma bolinha para a outra, o mouse cruza o vão
                // entre elas: espera um instante antes de esconder os símbolos,
                // para não piscar.
                auto *matsuSaida = new QTimer(matsuEu);
                matsuSaida->setSingleShot(true);
                matsuSaida->setInterval(90);

                QObject *matsuGrupo = matsuEu->parent() ? matsuEu->parent() : static_cast<QObject *>(matsuEu->decoration());
                const auto matsuDoGrupo = [matsuGrupo]() {
                    QList<Button *> lista;
                    const auto filhos = matsuGrupo->findChildren<Button *>();
                    for (Button *b : filhos) {
                        const auto t = b->type();
                        if (t == DecorationButtonType::Close || t == DecorationButtonType::Minimize || t == DecorationButtonType::Maximize) {
                            lista << b;
                        }
                    }
                    return lista;
                };
                const auto matsuIrPara = [matsuAnim, matsuEu](qreal alvo) {
                    if (qFuzzyCompare(matsuAnim->endValue().toReal() + 1.0, alvo + 1.0)) {
                        return;
                    }
                    const QVariant atual = matsuAnim->currentValue();
                    const qreal agora = atual.isValid() ? atual.toReal() : 0.0;
                    const auto d = qobject_cast<Decoration *>(matsuEu->decoration());
                    const bool anima = d && d->animationsDuration() > 0;
                    matsuAnim->stop();
                    matsuAnim->setStartValue(agora);
                    matsuAnim->setEndValue(alvo);
                    // Aparecer com calma (220 ms) e sumir um pouco mais rápido (150 ms).
                    matsuAnim->setDuration(anima ? qMax(1, int(qAbs(alvo - agora) * (alvo > agora ? 220 : 150))) : 0);
                    matsuAnim->start();
                };
                const auto matsuOlhar = [matsuDoGrupo, matsuIrPara, matsuSaida]() {
                    bool algum = false;
                    const auto lista = matsuDoGrupo();
                    for (Button *b : lista) {
                        algum = algum || b->isHovered();
                    }
                    if (algum) {
                        matsuSaida->stop();
                        matsuIrPara(1.0);
                    } else if (!matsuSaida->isActive()) {
                        matsuSaida->start();
                    }
                };
                QObject::connect(matsuSaida, &QTimer::timeout, matsuEu, [matsuDoGrupo, matsuIrPara]() {
                    const auto lista = matsuDoGrupo();
                    for (Button *b : lista) {
                        if (b->isHovered()) {
                            return;
                        }
                    }
                    matsuIrPara(0.0);
                });
                const auto lista = matsuDoGrupo();
                for (Button *b : lista) {
                    QObject::connect(b, &KDecoration3::DecorationButton::hoveredChanged, matsuEu, matsuOlhar);
                }
            }

            const QVariant matsuValor = matsuAnim->currentValue();
            const qreal matsuP = qBound(0.0, matsuValor.isValid() ? matsuValor.toReal() : 0.0, 1.0);
            const qreal matsuVisivel = QEasingCurve(QEasingCurve::OutCubic).valueForProgress(matsuP);
            QEasingCurve matsuPulo(QEasingCurve::OutBack);
            matsuPulo.setOvershoot(2.2);
            const qreal matsuTamanho = 0.4 + 0.6 * matsuPulo.valueForProgress(matsuP);

            // Segundo plano: cinza discreto, que vira cor conforme o mouse chega.
            qreal matsuCor = 1.0;
            if (!matsuAtiva && matsuDeco) {
                matsuCor = matsuVisivel;
                const QColor matsuCinza = KColorUtils::mix(matsuDeco->titleBarColor(), matsuDeco->fontColor(), 0.26);
                matsuFundo = KColorUtils::mix(matsuCinza, matsuFundo, matsuCor);
            }
            if (isPressed()) {
                matsuFundo = matsuFundo.darker(120);
            }

            const qreal matsuFino = qMax((qreal)1.0, 20 / width);
            painter->setPen(Qt::NoPen);
            painter->setBrush(matsuFundo);
            painter->drawEllipse(QRectF(1.5, 1.5, 15, 15));

            // Contorno bem fino, um tom abaixo, para dar acabamento (como no Mac).
            if (matsuCor > 0.01) {
                QPen matsuBorda(QColor(0, 0, 0, int(40 * matsuCor)));
                matsuBorda.setWidthF(0.8 * matsuFino);
                painter->setPen(matsuBorda);
                painter->setBrush(Qt::NoBrush);
                painter->drawEllipse(QRectF(1.9, 1.9, 14.2, 14.2));
            }

            if (matsuVisivel > 0.01) {
                painter->save();
                painter->setOpacity(painter->opacity() * matsuVisivel);
                painter->translate(9, 9);
                painter->scale(matsuTamanho, matsuTamanho);
                painter->translate(-9, -9);

                QPen matsuPena(matsuSimbolo);
                matsuPena.setCapStyle(Qt::RoundCap);
                matsuPena.setJoinStyle(Qt::RoundJoin);
                matsuPena.setWidthF(1.5 * matsuFino);
                painter->setPen(matsuPena);
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
                    matsuPena.setWidthF(0.8 * matsuFino);
                    painter->setPen(matsuPena);
                    painter->setBrush(matsuSimbolo);
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
    // ----- fim da parte do Matsu OS -----
