from fastapi import FastAPI

app = FastAPI(title='Lumera API', version='0.1.0')

@app.get('/health')
def health():
    return {'status':'ok','project':'Lumera'}

@app.get('/api/v1/status')
def status():
    return {'model_loaded':False,'mode':'research','message':'No validated model checkpoint is loaded.'}
