FROM python:3.12-alpine
RUN pip install --no-cache-dir PyMySQL==1.1.1
WORKDIR /check
COPY check.py ./
USER 65534
CMD ["python", "check.py"]
