# 1. Backend (loads .env, runs Spring Boot on port 8000)
./Learnova/scripts/run-dev.ps1

#    or manually:
cd Learnova
foreach ($l in Get-Content .env | Where-Object { $_ -match '^[A-Za-z_]+=' }) {
  $n,$v = $l -split '=', 2; [Environment]::SetEnvironmentVariable($n,$v,'Process')
}
mvn spring-boot:run

# 2. Frontend (static server, no build step)
cd Learnova/frontend
python -m http.server 3000     # open http://localhost:3000/index.html

# 3. URLs
#    Swagger:      http://localhost:8000/swagger-ui/index.html
#    Health:       http://localhost:8000/actuator/health