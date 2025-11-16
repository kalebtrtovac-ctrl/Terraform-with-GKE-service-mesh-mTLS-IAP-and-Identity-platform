# Dockerfile for Tetris web application on python:3.12-slim
FROM python:3.12-slim

RUN useradd --create-home --shell /sbin/nologin appuser \
  && mkdir -p /home/appuser/tetris \
  && chown -R appuser:appuser /home/appuser/tetris

WORKDIR /home/appuser/tetris

COPY index.html ./index.html
COPY start.sh ./start.sh

RUN chmod 755 ./start.sh \
  && chown appuser:appuser ./index.html ./start.sh

USER appuser
ENV PORT=8080
EXPOSE 8080

CMD ["./start.sh"]