"""
Bulk Job Store
==============
Port of: lib/bulk/job-store.js

In-memory storage for bulk API jobs (v1 and v2).
Singleton class replacing Node.js factory function.

Job States:
  Open -> UploadComplete -> InProgress -> JobComplete
  Open -> Aborted
  Any -> Failed
"""
from datetime import datetime, timezone
from salesforce_mock.utils.id_generator import generate_id


class JobStore:
    """Manages bulk job state for all Bulk API versions."""

    def __init__(self):
        self._jobs = {}

    def create(self, config):
        """Create a new bulk job."""
        job_id = generate_id('750')
        now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        job = {
            'id': job_id,
            'operation': config.get('operation', 'insert'),
            'object': config.get('object', ''),
            'contentType': config.get('contentType', 'CSV'),
            'state': 'Open',
            'createdDate': now,
            'systemModstamp': now,
            'jobType': config.get('jobType', 'V2Ingest'),
            'lineEnding': config.get('lineEnding', 'LF'),
            'columnDelimiter': config.get('columnDelimiter', 'COMMA'),
            'externalIdFieldName': config.get('externalIdFieldName', ''),
            'query': config.get('query', ''),  # SOQL query for V2Query jobs
            'numberRecordsProcessed': 0,
            'numberRecordsFailed': 0,
            'batches': [],
            'results': {'successful': [], 'failed': [], 'unprocessed': []},
        }
        self._jobs[job_id] = job
        return job

    def get(self, job_id):
        """Get job by ID."""
        return self._jobs.get(job_id)

    def update(self, job_id, updates):
        """Update job fields."""
        job = self._jobs.get(job_id)
        if job:
            job.update(updates)
            job['systemModstamp'] = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        return job

    def remove(self, job_id):
        """Delete a job."""
        return self._jobs.pop(job_id, None)

    def list_jobs(self, job_type=None):
        """List jobs, optionally filtered by type."""
        jobs = list(self._jobs.values())
        if job_type:
            jobs = [j for j in jobs if j.get('jobType') == job_type]
        return {'done': True, 'records': jobs}

    def list_all(self):
        """Return all jobs."""
        jobs = list(self._jobs.values())
        return {'count': len(jobs), 'jobs': jobs}

    def clear(self):
        """Remove all jobs. Returns count cleared."""
        count = len(self._jobs)
        self._jobs.clear()
        return count


# Module-level singleton
job_store = JobStore()
