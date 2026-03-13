.PHONY: setup test test-verbose clean

setup:
	python -m pip install --upgrade pip
	python -m pip install -r requirements.txt

test:
	pytest -q tb/test_runner.py

test-verbose:
	pytest -vv tb/test_runner.py -s

clean:
	rm -rf sim_build .pytest_cache tb/__pycache__ tb/*.vcd tb/results.xml
