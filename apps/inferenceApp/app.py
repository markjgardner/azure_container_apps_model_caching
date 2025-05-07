from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def check_model_files():
    model_path = '/mnt/models'
    if os.path.exists(model_path):
        files = os.listdir(model_path)
        return f"Model files found: {', '.join(files)}"
    else:
        return "Model path does not exist."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)