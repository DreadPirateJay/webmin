line1=Configureerbare opties,11
login=Administratie login,0
pass=Administratie wachtwoord,12
sameunix=Unix gebruiker die verbind met de database als,1,1-Zelfde als Administratie login,0-root
perpage=Aantal rijen om te laten zien per pagina,0,5
style=Laat databasen en tabellen zien als,1,1-Lijst,0-Iconen,2-Alleen namen
add_mode=Gebruik een verticale rij bewerkings interface,1,1-Ja,0-Nee
blob_mode=Laat blob en tekst velden zien als,1,0-Data in tabel,1-Links om te downloaden
nodbi=Gebruik DBI om te verbinden indien beschikbaar?,1,0-Ja,1-Nee
date_subs=Doe <tt>strftime</tt> toevoegingen bij backup bestemmingen?,1,1-Ja,0-Nee
simple_sched=Geplande selector formaat,1,1-Simpel,0-Complex
encoding=Decoderen van database inhoud,3,Standaard (van huidige taal)
max_dbs=Maximum aantal databasen en tabellen om te laten zien,0,5
max_text=Maximum overzicht lengte voor tekst velden,3,Ongelimiteerd
line2=Systeem configuratie,11
psql=Pad naar de psql opdracht,0
plib=Pad naar PostgreSQL gedeelde bibliotheken,3,Niet nodig
basedb=Initialiseer PostgreSQL database,0
start_cmd=Opdracht om PostgreSQL te starten,0
stop_cmd=Opdracht om PostgreSQL te stoppen,3,Kil proces
setup_cmd=Opdracht om PostgreSQL te initialiseren,3,Geen
pid_file=Pad naar postmaster PID file,8
hba_conf=Pad naar de host toegang config file,9,60,3, \t
host=PostgreSQL host om mee te verbinden,3,localhost
port=PostgreSQL poort om mee te verbinden,3,Standaart
dump_cmd=Pad naar de pg_dump opdracht,0
rstr_cmd=Pad naar pg_restore opdracht,0
repository=Standaard backup repository directory,3,Geen
